#!/usr/bin/env bash
#
# Contract tests for install.sh and packages/linux.tsv.
#
#     bash ./tests/install.tests.sh
#
# Plain bash on purpose: the suite has to run on a bare Debian 13 userland, so
# it adds no test framework as a dependency.
#
# Every run of install.sh happens in a child process whose PATH holds nothing
# but fake executables plus a few coreutils symlinks, with HOME inside a
# temporary sandbox, with an injected os-release and with a proxy pointing at a
# closed port. No test touches the real apt, the real home directory or the
# network.
#
# Package and command names are read from packages/linux.tsv: adding or
# removing a package there needs no change in this file.

set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
package_file="$repo_root/packages/linux.tsv"
install_script="$repo_root/install.sh"

# Only these coreutils are visible to install.sh, so a tool that happens to be
# installed on the machine running the tests can never change the result.
stub_tools=(cat chmod cp dirname env gzip mkdir mktemp rm sha256sum tar uname)

tests_run=0
tests_failed=0
current_failed=0
sandboxes=()

sandbox=''
repo=''
fake_bin=''
log_dir=''
home_dir=''
output=''
status=0

##### Harness #####

fail() {
    current_failed=1
    printf '     %s\n' "$*" >&2
}

assert_status() {
    if [[ $1 != "$2" ]]; then
        fail "expected exit status $1, got $2"
    fi
}

assert_status_not() {
    if [[ $1 == "$2" ]]; then
        fail "expected an exit status other than $1"
    fi
}

assert_contains() {
    if [[ $1 != *"$2"* ]]; then
        fail "${3:-output} should contain '$2'"
    fi
}

assert_not_contains() {
    if [[ $1 == *"$2"* ]]; then
        fail "${3:-output} should not contain '$2'"
    fi
}

assert_empty() {
    if [[ -n $1 ]]; then
        fail "${2:-value} should be empty, was '$1'"
    fi
}

skip() {
    printf '     skipped: %s\n' "$*"
}

run_test() {
    local name=$1 fn=$2
    current_failed=0
    tests_run=$((tests_run + 1))

    local test_status=0
    "$fn" || test_status=$?
    if ((test_status != 0)); then
        current_failed=1
        printf '     the test itself exited with %s\n' "$test_status" >&2
    fi

    if ((current_failed)); then
        tests_failed=$((tests_failed + 1))
        printf 'FAIL %s\n' "$name"
        if [[ -n $output ]]; then
            printf '%s\n' "$output" | sed 's/^/       > /'
        fi
    else
        printf 'ok   %s\n' "$name"
    fi
    output=''
}

cleanup() {
    local dir
    for dir in ${sandboxes[@]+"${sandboxes[@]}"}; do
        rm -rf -- "$dir"
    done
}
trap cleanup EXIT

##### Package definition #####

# The rows of packages/linux.tsv, without comments and blank lines.
tsv_rows() {
    awk -F'\t' '$0 !~ /^#/ && NF > 0' "$package_file"
}

# Field $1 of the rows whose tier matches $2 and whose source matches $3; an
# empty $2 or $3 matches everything.
tsv_field() {
    tsv_rows | awk -F'\t' -v field="$1" -v tier="$2" -v source="$3" '
        (tier == "" || $1 == tier) && (source == "" || $2 == source) { print $field }'
}

##### Sandbox #####

new_sandbox() {
    sandbox="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install-test.XXXXXX")"
    sandboxes+=("$sandbox")

    # The repository copy has a space in its path so that quoting stays covered.
    repo="$sandbox/dot files"
    fake_bin="$sandbox/bin"
    log_dir="$sandbox/log"
    home_dir="$sandbox/home"

    mkdir -p "$repo" "$fake_bin" "$sandbox/stub" "$log_dir" "$home_dir"
    cp "$install_script" "$repo/install.sh"
    cp "$repo_root/.chezmoiroot" "$repo/.chezmoiroot"
    cp -R "$repo_root/packages" "$repo/packages"
    cp -R "$repo_root/home" "$repo/home"

    local tool
    for tool in "${stub_tools[@]}"; do
        ln -s "$(command -v "$tool")" "$sandbox/stub/$tool"
    done

    write_os_release 'debian' '13'

    # package -> command, so the fakes hardcode no package name either.
    tsv_rows | awk -F'\t' '$2 == "apt" { print $3 "\t" $4 }' >"$sandbox/pkgmap"
}

write_os_release() {
    cat >"$sandbox/os-release" <<EOF
PRETTY_NAME="fixture"
NAME="fixture"
ID=$1
VERSION_ID="$2"
EOF
}

# Writes an executable that logs its arguments and then runs the body read from
# stdin, so the tests observe a real process boundary.
write_fake() {
    local name=$1
    {
        printf '#!%s\n' "$BASH"
        printf 'printf "%%s\\n" "$*" >>"%s/%s"\n' "$log_dir" "$name"
        cat
    } >"$fake_bin/$name"
    chmod 0755 "$fake_bin/$name"
}

fake_sudo() {
    write_fake sudo <<'EOF'
exec "$@"
EOF
}

# 'install' creates the command each installed package provides, so the next
# presence check sees it. A package named in APT_FAIL aborts the whole batch,
# the way apt-get aborts a transaction it cannot satisfy.
fake_apt_get() {
    write_fake apt-get <<EOF
bin_dir='$fake_bin'
map='$sandbox/pkgmap'
EOF
    cat >>"$fake_bin/apt-get" <<'EOF'
action=""
names=()
for arg in "$@"; do
    case $arg in
    -*) ;;
    update | install) [[ -z $action ]] && action=$arg ;;
    *) names+=("$arg") ;;
    esac
done
[[ $action == install ]] || exit 0

for name in ${names[@]+"${names[@]}"}; do
    if [[ -n ${APT_FAIL:-} && $name == "$APT_FAIL" ]]; then
        printf 'E: Unable to locate package %s\n' "$name" >&2
        exit 100
    fi
done

for name in ${names[@]+"${names[@]}"}; do
    while IFS=$'\t' read -r package provided; do
        [[ $package == "$name" ]] || continue
        printf '#!/bin/sh\nexit 0\n' >"$bin_dir/$provided"
        chmod 0755 "$bin_dir/$provided"
    done <"$map"
done
EOF
}

fake_dpkg_query() {
    write_fake dpkg-query <<EOF
bin_dir='$fake_bin'
map='$sandbox/pkgmap'
EOF
    cat >>"$fake_bin/dpkg-query" <<'EOF'
name=""
for arg in "$@"; do
    case $arg in
    -* | '${db:Status-Status}') ;;
    *) name=$arg ;;
    esac
done
while IFS=$'\t' read -r package provided; do
    if [[ $package == "$name" && -x $bin_dir/$provided ]]; then
        printf 'installed'
        exit 0
    fi
done <"$map"
exit 1
EOF
}

fake_chezmoi() {
    write_fake chezmoi <<'EOF'
exit "${FAKE_CHEZMOI_EXIT:-0}"
EOF
}

# Serves the chezmoi release install.sh asks for. The archive is built once and
# cached so that the checksum file served afterwards matches it.
fake_curl() {
    write_fake curl <<EOF
cache='$sandbox/curl-cache'
log_dir='$log_dir'
EOF
    cat >>"$fake_bin/curl" <<'EOF'
if [[ -n ${FAKE_CURL_FAIL:-} ]]; then
    printf 'curl: (22) simulated download failure\n' >&2
    exit 22
fi

output=""
url=""
previous=""
for arg in "$@"; do
    [[ $previous == --output ]] && output=$arg
    case $arg in
    http*) url=$arg ;;
    esac
    previous=$arg
done

mkdir -p "$cache"
archive="$cache/chezmoi.tar.gz"
if [[ ! -f $archive ]]; then
    mkdir -p "$cache/payload"
    {
        printf '#!/bin/sh\n'
        printf 'printf "%%s\\n" "$*" >>"%s/chezmoi"\n' "$log_dir"
        printf 'exit "${FAKE_CHEZMOI_EXIT:-0}"\n'
    } >"$cache/payload/chezmoi"
    chmod 0755 "$cache/payload/chezmoi"
    tar -czf "$archive" -C "$cache/payload" chezmoi
fi

case $url in
*.tar.gz)
    printf '%s' "${url##*/}" >"$cache/archive-name"
    cp "$archive" "$output"
    ;;
*checksums.txt)
    read -r name <"$cache/archive-name"
    sum="$(sha256sum "$archive")"
    printf '%s  %s\n' "${sum%% *}" "$name" >"$output"
    ;;
*)
    printf 'curl: (22) unexpected url %s\n' "$url" >&2
    exit 22
    ;;
esac
EOF
}

standard_fakes() {
    fake_apt_get
    fake_dpkg_query
    fake_sudo
    fake_chezmoi
}

# A machine on which every command of the definition already exists, so nothing
# has to be installed. Fakes written earlier are kept.
fake_every_command() {
    local provided
    while read -r provided; do
        if [[ ! -e $fake_bin/$provided ]]; then
            printf '#!/bin/sh\nexit 0\n' >"$fake_bin/$provided"
            chmod 0755 "$fake_bin/$provided"
        fi
    done < <(tsv_field 4 '' '')
}

run_installer() {
    set +e
    output="$(
        env -i \
            PATH="$fake_bin:$sandbox/stub" \
            HOME="$home_dir" \
            USER='tester' \
            DOTFILES_OS_RELEASE="$sandbox/os-release" \
            APT_FAIL="${APT_FAIL:-}" \
            FAKE_CHEZMOI_EXIT="${FAKE_CHEZMOI_EXIT:-}" \
            FAKE_CURL_FAIL="${FAKE_CURL_FAIL:-}" \
            HTTPS_PROXY='http://127.0.0.1:1' \
            https_proxy='http://127.0.0.1:1' \
            "$BASH" "$repo/install.sh" "$@" 2>&1
    )"
    status=$?
    set -e
}

log_of() {
    if [[ -f $log_dir/$1 ]]; then
        cat -- "$log_dir/$1"
    fi
}

home_entries() {
    find "$home_dir" -mindepth 1 | sort | tr '\n' ' '
}

##### Static contracts #####

test_syntax() {
    if ! bash -n "$install_script"; then
        fail 'bash -n install.sh failed'
    fi
    if [[ ! -x $install_script ]]; then
        fail 'install.sh is not executable'
    fi
    if [[ "$(head -n 1 "$install_script")" != '#!/usr/bin/env bash' ]]; then
        fail 'install.sh should start with #!/usr/bin/env bash'
    fi
    if ! grep -q 'set -Eeuo pipefail' "$install_script"; then
        fail 'install.sh should use set -Eeuo pipefail'
    fi
}

test_shellcheck() {
    if ! command -v shellcheck >/dev/null 2>&1; then
        skip 'shellcheck is not installed'
        return 0
    fi
    # Warnings and errors only: style and info findings must not turn into
    # maintenance noise.
    if ! shellcheck --severity=warning --shell=bash "$install_script"; then
        fail 'shellcheck reported a warning or an error'
    fi
}

test_definition_fields() {
    local line
    while IFS= read -r line; do
        local -a fields=()
        IFS=$'\t' read -r -a fields <<<"$line"
        if ((${#fields[@]} != 5)); then
            fail "row '$line' has ${#fields[@]} fields, expected 5"
            continue
        fi
        local field
        for field in "${fields[@]}"; do
            if [[ -z ${field// /} ]]; then
                fail "row '$line' has an empty field"
            fi
        done
    done < <(tsv_rows)

    if [[ -z "$(tsv_rows)" ]]; then
        fail 'the package definition lists no package'
    fi
    if [[ -n "$(tail -c 1 "$package_file")" ]]; then
        fail 'the package definition should end with a newline'
    fi
}

test_definition_tiers_and_sources() {
    local tier source
    while read -r tier; do
        case $tier in
        required | optional) ;;
        *) fail "unknown tier '$tier'" ;;
        esac
    done < <(tsv_field 1 '' '')

    while read -r source; do
        case $source in
        apt | upstream | none) ;;
        *) fail "unknown source '$source'" ;;
        esac
    done < <(tsv_field 2 '' '')

    # chezmoi drives the bootstrap itself, so it has to stay required.
    if [[ "$(tsv_rows | awk -F'\t' '$3 == "chezmoi" { print $1 }')" != 'required' ]]; then
        fail 'chezmoi should be a required package'
    fi
}

test_definition_uniqueness() {
    local duplicates
    duplicates="$(tsv_field 3 '' '' | sort | uniq -d | tr '\n' ' ')"
    if [[ -n ${duplicates// /} ]]; then
        fail "these packages are listed twice: $duplicates"
    fi

    duplicates="$(tsv_field 4 '' '' | sort | uniq -d | tr '\n' ' ')"
    if [[ -n ${duplicates// /} ]]; then
        fail "these commands are claimed by more than one package: $duplicates"
    fi
}

test_definition_scope() {
    # apt only, and no AI coding agent, runtime or container tooling.
    local forbidden='\b(snap|flatpak|brew|linuxbrew|nix|pacman|dnf|yum|winget|scoop|omp|claude|codex|docker|podman|nodejs|bun|pipx)\b'
    local hits
    hits="$(tsv_rows | grep -Ein "$forbidden" || true)"
    if [[ -n $hits ]]; then
        fail "the package definition mentions something out of scope: $hits"
    fi
}

test_installer_scope() {
    local hits
    hits="$(grep -Ein '\b(add-apt-repository|apt-add-repository|snap|flatpak|linuxbrew|pacman|dnf|yum)\b' "$install_script" || true)"
    if [[ -n $hits ]]; then
        fail "install.sh should only use apt-get: $hits"
    fi

    hits="$(grep -Ein '(curl|wget)[^|#]*\|[[:space:]]*(ba)?sh' "$install_script" || true)"
    if [[ -n $hits ]]; then
        fail "install.sh should never pipe a download into a shell: $hits"
    fi

    hits="$(grep -Ein 'sources\.list|/etc/apt/' "$install_script" || true)"
    if [[ -n $hits ]]; then
        fail "install.sh should not touch the apt configuration: $hits"
    fi

    if ! grep -q 'https://github.com/twpayne/chezmoi/releases' "$install_script"; then
        fail 'the chezmoi download should come from the official upstream repository'
    fi
}

##### Command line #####

test_help() {
    new_sandbox
    standard_fakes
    run_installer --help
    assert_status 0 "$status"
    local option
    for option in --dry-run --skip-packages --skip-optional --skip-chezmoi-install; do
        assert_contains "$output" "$option" 'the help text'
    done
    assert_empty "$(log_of apt-get)" 'the apt-get log'
}

test_unknown_option() {
    new_sandbox
    standard_fakes
    run_installer --frobnicate
    assert_status_not 0 "$status"
    assert_contains "$output" 'unknown option' 'the error message'
    assert_empty "$(log_of chezmoi)" 'the chezmoi log'
}

##### Normal path #####

test_normal_run() {
    new_sandbox
    standard_fakes
    run_installer
    assert_status 0 "$status"

    local apt_log updates
    apt_log="$(log_of apt-get)"
    updates="$(grep -c '^update' <<<"$apt_log" || true)"
    if [[ $updates != '1' ]]; then
        fail "apt-get update should run exactly once, ran $updates times"
    fi

    local package
    while read -r package; do
        assert_contains "$apt_log" "$package" 'the apt-get log'
    done < <(tsv_field 3 '' 'apt')

    assert_contains "$(log_of chezmoi)" "init --apply --source $repo" 'the chezmoi log'
    assert_contains "$output" 'Summary' 'the output'

    # The fake chezmoi writes nothing, so nothing else may have written either.
    assert_empty "$(home_entries)" 'the sandbox home'
}

test_dry_run() {
    new_sandbox
    standard_fakes
    run_installer --dry-run
    assert_status 0 "$status"
    assert_contains "$output" 'would run:' 'the plan'
    assert_contains "$output" 'apt-get install' 'the plan'
    assert_contains "$output" 'init --apply --source' 'the plan'

    assert_empty "$(log_of apt-get)" 'the apt-get log'
    assert_empty "$(log_of chezmoi)" 'the chezmoi log'
    assert_empty "$(log_of curl)" 'the curl log'
    assert_empty "$(home_entries)" 'the sandbox home'
}

test_skip_packages() {
    new_sandbox
    standard_fakes
    run_installer --skip-packages
    assert_status 0 "$status"
    assert_empty "$(log_of apt-get)" 'the apt-get log'
    assert_contains "$(log_of chezmoi)" 'init --apply' 'the chezmoi log'
}

test_skip_optional() {
    new_sandbox
    standard_fakes
    run_installer --skip-optional
    assert_status 0 "$status"

    local apt_log package
    apt_log="$(log_of apt-get)"
    while read -r package; do
        assert_contains "$apt_log" "$package" 'the apt-get log'
    done < <(tsv_field 3 'required' 'apt')
    while read -r package; do
        assert_not_contains "$apt_log" "$package" 'the apt-get log'
    done < <(tsv_field 3 'optional' 'apt')
    assert_contains "$(log_of chezmoi)" 'init --apply' 'the chezmoi log'
}

##### Environment failures #####

test_unsupported_distro() {
    new_sandbox
    standard_fakes
    write_os_release 'ubuntu' '24.04'
    run_installer
    assert_status_not 0 "$status"
    assert_contains "$output" 'Debian' 'the error message'
    assert_empty "$(log_of apt-get)" 'the apt-get log'
    assert_empty "$(log_of chezmoi)" 'the chezmoi log'
}

test_unsupported_debian_version() {
    new_sandbox
    standard_fakes
    write_os_release 'debian' '12'
    run_installer
    assert_status_not 0 "$status"
    assert_contains "$output" 'VERSION_ID' 'the error message'
    assert_empty "$(log_of apt-get)" 'the apt-get log'
}

test_missing_apt() {
    new_sandbox
    fake_dpkg_query
    fake_sudo
    fake_chezmoi
    run_installer
    assert_status_not 0 "$status"
    assert_contains "$output" 'apt-get' 'the error message'
    assert_empty "$(log_of chezmoi)" 'the chezmoi log'
}

test_missing_sudo() {
    if ((EUID == 0)); then
        skip 'this run is root, so sudo is never needed'
        return 0
    fi
    new_sandbox
    fake_apt_get
    fake_dpkg_query
    fake_chezmoi
    run_installer
    assert_status_not 0 "$status"
    assert_contains "$output" 'sudo' 'the error message'
    assert_empty "$(log_of apt-get)" 'the apt-get log'
    assert_empty "$(log_of chezmoi)" 'the chezmoi log'
}

test_missing_sudo_but_all_present() {
    new_sandbox
    fake_apt_get
    fake_dpkg_query
    fake_chezmoi
    fake_every_command
    run_installer
    assert_status 0 "$status"
    assert_empty "$(log_of apt-get)" 'the apt-get log'
    assert_contains "$(log_of chezmoi)" 'init --apply' 'the chezmoi log'
}

##### Install failures #####

test_required_failure() {
    new_sandbox
    standard_fakes
    APT_FAIL="$(tsv_field 3 'required' 'apt' | head -n 1)"
    run_installer
    local failing=$APT_FAIL
    unset APT_FAIL
    assert_status_not 0 "$status"
    assert_contains "$output" 'required' 'the error message'
    assert_contains "$output" "$failing" 'the error message'
    assert_empty "$(log_of chezmoi)" 'the chezmoi log'
}

test_optional_failure() {
    new_sandbox
    standard_fakes
    local failing
    failing="$(tsv_field 3 'optional' 'apt' | head -n 1)"
    APT_FAIL="$failing"
    run_installer
    unset APT_FAIL
    assert_status 0 "$status"

    # The batch aborts and the packages are retried one by one, so exactly the
    # one package that cannot be installed shows up as an optional failure.
    assert_contains "$output" 'one by one' 'the output'
    assert_contains "$output" "optional failures: $failing" 'the summary'
    assert_contains "$(log_of chezmoi)" 'init --apply' 'the chezmoi log'
}

test_chezmoi_exit_code() {
    new_sandbox
    standard_fakes
    FAKE_CHEZMOI_EXIT=7
    run_installer
    unset FAKE_CHEZMOI_EXIT
    assert_status 7 "$status"
    assert_contains "$output" 'chezmoi exited with code 7' 'the error message'
}

test_idempotent_run() {
    new_sandbox
    standard_fakes
    fake_every_command
    run_installer
    assert_status 0 "$status"
    assert_empty "$(log_of apt-get)" 'the apt-get log'
    assert_contains "$output" 'already present:' 'the summary'
    assert_empty "$(home_entries)" 'the sandbox home'
}

##### chezmoi bootstrap #####

test_chezmoi_from_upstream() {
    new_sandbox
    fake_apt_get
    fake_dpkg_query
    fake_sudo
    fake_curl
    run_installer
    assert_status 0 "$status"

    local curl_log
    curl_log="$(log_of curl)"
    assert_contains "$curl_log" 'https://github.com/twpayne/chezmoi/releases/download/' 'the curl log'
    assert_contains "$curl_log" 'checksums.txt' 'the curl log'

    if [[ ! -x $home_dir/.local/bin/chezmoi ]]; then
        fail 'chezmoi should be installed into ~/.local/bin'
    fi
    assert_contains "$(log_of chezmoi)" 'init --apply' 'the chezmoi log'
}

test_chezmoi_download_failure() {
    new_sandbox
    fake_apt_get
    fake_dpkg_query
    fake_sudo
    fake_curl
    FAKE_CURL_FAIL=1
    run_installer
    unset FAKE_CURL_FAIL
    assert_status_not 0 "$status"
    assert_contains "$output" 'downloading' 'the error message'
    if [[ -e $home_dir/.local/bin/chezmoi ]]; then
        fail 'a failed download must not leave a chezmoi binary behind'
    fi
}

test_skip_chezmoi_install() {
    new_sandbox
    fake_apt_get
    fake_dpkg_query
    fake_sudo
    fake_curl
    run_installer --skip-chezmoi-install
    assert_status_not 0 "$status"
    assert_contains "$output" 'chezmoi' 'the error message'
    assert_empty "$(log_of curl)" 'the curl log'
}

##### Runner #####

printf 'install.sh contract tests\n\n'

run_test 'install.sh parses and is executable' test_syntax
run_test 'install.sh passes shellcheck' test_shellcheck
run_test 'the package definition has five filled fields per row' test_definition_fields
run_test 'the package definition uses known tiers and sources' test_definition_tiers_and_sources
run_test 'the package definition lists no package or command twice' test_definition_uniqueness
run_test 'the package definition stays inside the bootstrap scope' test_definition_scope
run_test 'install.sh uses apt-get only and pipes nothing into a shell' test_installer_scope
run_test '--help lists every option' test_help
run_test 'an unknown option fails' test_unknown_option
run_test 'a normal run installs the packages and applies chezmoi' test_normal_run
run_test 'a dry run changes nothing' test_dry_run
run_test '--skip-packages goes straight to chezmoi' test_skip_packages
run_test '--skip-optional installs the required packages only' test_skip_optional
run_test 'another distribution fails before apt' test_unsupported_distro
run_test 'another Debian release fails before apt' test_unsupported_debian_version
run_test 'a missing apt-get fails' test_missing_apt
run_test 'a missing sudo fails when packages are missing' test_missing_sudo
run_test 'a missing sudo is fine when every package is present' test_missing_sudo_but_all_present
run_test 'a required package failure stops the run' test_required_failure
run_test 'an optional package failure only warns' test_optional_failure
run_test 'the chezmoi exit code is preserved' test_chezmoi_exit_code
run_test 'a second run installs nothing' test_idempotent_run
run_test 'chezmoi is fetched from its official release' test_chezmoi_from_upstream
run_test 'a failed chezmoi download fails the run' test_chezmoi_download_failure
run_test '--skip-chezmoi-install fails instead of downloading' test_skip_chezmoi_install

printf '\n%s tests, %s failed\n' "$tests_run" "$tests_failed"
if ((tests_failed > 0)); then
    exit 1
fi
