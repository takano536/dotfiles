#!/usr/bin/env bash
#
# Bootstraps a Debian GNU/Linux 13 (trixie) machine from this chezmoi source
# repository: installs the packages listed in packages/linux.tsv with apt,
# makes sure chezmoi is available and runs 'chezmoi init --apply' with this
# repository as the chezmoi source directory. Safe to run repeatedly.
#
#     bash ./install.sh [--dry-run] [--skip-packages] [--skip-optional]
#                       [--skip-chezmoi-install] [--help]
#
# Run it as the user the dotfiles belong to, never as 'sudo ./install.sh':
# only the apt calls are elevated, so chezmoi writes into the right home
# directory.

set -Eeuo pipefail

readonly script_name='install.sh'

# The only officially supported target. Everything below assumes Debian's apt
# and Debian's package and binary names, so another distribution gets a clear
# message instead of a half-working run.
readonly supported_id='debian'
readonly supported_version_id='13'

# chezmoi is not in Debian 13, so it is fetched from its own GitHub release.
# Pinned instead of resolved at runtime: a bootstrap should install the same
# version on every machine, and it avoids parsing the GitHub API.
readonly chezmoi_version='2.72.0'
readonly chezmoi_release_url="https://github.com/twpayne/chezmoi/releases/download/v${chezmoi_version}"

dry_run=0
skip_packages=0
skip_optional=0
skip_chezmoi_install=0

# Package definition, filled by load_packages from packages/linux.tsv.
pkg_tier=()
pkg_source=()
pkg_name=()
pkg_command=()

# Run state, reported by the summary.
state_present=()
state_installed=()
state_planned=()
state_optional_failures=()
state_required_failures=()
state_notes=()

apt_prefix=()
apt_updated=0
chezmoi_bin=''
tmp_dir=''

##### Output #####

step() { printf '\n==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '    warning: %s\n' "$*" >&2; }

note() {
    info "$*"
    state_notes+=("$*")
}

die() {
    printf '%s: %s\n' "$script_name" "$*" >&2
    exit 1
}

# A failing command anywhere else is a bug in this script; report it in one
# line with the location instead of letting bash die silently.
trap 'status=$?; printf "%s: unexpected failure at line %s (exit %s). Nothing after that step ran.\n" "$script_name" "$LINENO" "$status" >&2; exit "$status"' ERR

trap 'if [[ -n ${tmp_dir:-} && -d ${tmp_dir:-} ]]; then rm -rf -- "$tmp_dir"; fi' EXIT

usage() {
    cat <<EOF
Usage: bash ./install.sh [options]

Bootstraps Debian ${supported_version_id} from this chezmoi source repository.

Options:
  --dry-run               Print the plan; install nothing, download nothing and
                          leave the home directory untouched.
  --skip-packages         Do not install any package except chezmoi itself.
  --skip-optional         Install the required packages but not the optional
                          CLI and TUI tools.
  --skip-chezmoi-install  Fail instead of installing chezmoi when it is missing.
  -h, --help              Show this help.
EOF
}

##### Command line #####

parse_args() {
    while (($# > 0)); do
        case $1 in
        --dry-run) dry_run=1 ;;
        --skip-packages) skip_packages=1 ;;
        --skip-optional) skip_optional=1 ;;
        --skip-chezmoi-install) skip_chezmoi_install=1 ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            printf '%s: unknown option '\''%s'\''.\n\n' "$script_name" "$1" >&2
            usage >&2
            exit 2
            ;;
        esac
        shift
    done
}

##### Repository #####

# Resolved from the location of this script, not from the working directory,
# so 'bash /some/where/dotfiles/install.sh' works from anywhere.
resolve_repo() {
    repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

    local chezmoi_root_file="$repo_root/.chezmoiroot"
    if [[ ! -f $chezmoi_root_file ]]; then
        die "'$chezmoi_root_file' was not found, so '$repo_root' is not this dotfiles repository. Run install.sh from the repository it was cloned into."
    fi

    # A single line naming the source subdirectory; tolerate CRLF checkouts.
    local chezmoi_root
    IFS= read -r chezmoi_root <"$chezmoi_root_file" || true
    chezmoi_root="${chezmoi_root%$'\r'}"
    if [[ -z $chezmoi_root ]]; then
        die "'$chezmoi_root_file' is empty, so the chezmoi source directory is unknown. Check out the repository again."
    fi
    source_dir="$repo_root/$chezmoi_root"
    if [[ ! -d $source_dir ]]; then
        die "the chezmoi source directory '$source_dir' referenced by .chezmoiroot is missing. Check out the repository again."
    fi

    package_file="$repo_root/packages/linux.tsv"
    if [[ ! -f $package_file ]]; then
        die "the package list '$package_file' was not found. Check out the repository again, or use --skip-packages to only apply the dotfiles."
    fi
}

##### Distribution #####

# DOTFILES_OS_RELEASE exists so the tests can point this at a fixture; a normal
# run always reads /etc/os-release.
os_release_file() { printf '%s' "${DOTFILES_OS_RELEASE:-/etc/os-release}"; }

require_supported_distro() {
    local file
    file="$(os_release_file)"
    if [[ ! -r $file ]]; then
        die "'$file' is not readable, so the distribution cannot be identified. This installer supports Debian ${supported_version_id} only."
    fi

    local key value
    distro_id=''
    distro_version_id=''
    while IFS='=' read -r key value; do
        # os-release values may be quoted with single or double quotes.
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"
        case $key in
        ID) distro_id=$value ;;
        VERSION_ID) distro_version_id=$value ;;
        esac
    done <"$file"

    if [[ $distro_id != "$supported_id" || $distro_version_id != "$supported_version_id" ]]; then
        die "this installer supports Debian GNU/Linux ${supported_version_id} (trixie) only, but ${file} reports ID='${distro_id}' VERSION_ID='${distro_version_id}'. Nothing was installed. On another system, install chezmoi yourself and run: chezmoi init --apply --source '${repo_root}'"
    fi
}

##### Package definition #####

load_packages() {
    local line_number=0 tier source name command why
    while IFS=$'\t' read -r tier source name command why || [[ -n ${tier:-} ]]; do
        line_number=$((line_number + 1))
        if [[ -z $tier || $tier == '#'* ]]; then
            continue
        fi
        if [[ -z $source || -z $name || -z $command || -z $why ]]; then
            die "$package_file line $line_number: every row needs the tab separated fields tier, source, package, command and reason."
        fi
        case $tier in
        required | optional) ;;
        *) die "$package_file line $line_number: unknown tier '$tier' (expected 'required' or 'optional')." ;;
        esac
        case $source in
        apt | upstream | none) ;;
        *) die "$package_file line $line_number: unknown source '$source' (expected 'apt', 'upstream' or 'none')." ;;
        esac

        pkg_tier+=("$tier")
        pkg_source+=("$source")
        pkg_name+=("$name")
        pkg_command+=("$command")
    done <"$package_file"

    if ((${#pkg_name[@]} == 0)); then
        die "$package_file lists no package."
    fi
}

# A package counts as installed when its command resolves. ca-certificates and
# friends install outside a normal user's PATH, so dpkg is asked as well before
# apt is invoked again.
package_present() {
    local index=$1

    if command -v -- "${pkg_command[index]}" >/dev/null 2>&1; then
        return 0
    fi

    if [[ ${pkg_source[index]} == 'apt' ]] && command -v dpkg-query >/dev/null 2>&1; then
        local status
        status="$(dpkg-query -W -f='${db:Status-Status}' -- "${pkg_name[index]}" 2>/dev/null || true)"
        if [[ $status == 'installed' ]]; then
            return 0
        fi
    fi

    return 1
}

##### apt #####

require_apt() {
    if ! command -v apt-get >/dev/null 2>&1; then
        die "apt-get was not found, but it is the only package manager this installer uses. Install apt or run install.sh --skip-packages to only apply the dotfiles."
    fi
}

# Only the apt calls are elevated. Resolved lazily, so a machine that already
# has every package needs neither root nor sudo.
require_apt_privileges() {
    if ((EUID == 0)); then
        return 0
    fi
    if command -v sudo >/dev/null 2>&1; then
        apt_prefix=(sudo)
        return 0
    fi
    if ((dry_run)); then
        note "sudo is not installed; a real run would need root or sudo for apt-get."
        return 0
    fi
    die "packages have to be installed, but this run is not root and sudo was not found. Install sudo (or run the apt-get commands as root) and try again."
}

run() {
    if ((dry_run)); then
        info "would run: $*"
        return 0
    fi
    "$@"
}

# DEBIAN_FRONTEND is passed through env because sudo resets the environment,
# and it is what keeps dpkg from opening configuration dialogs.
apt_get() {
    run "${apt_prefix[@]}" env DEBIAN_FRONTEND=noninteractive apt-get "$@"
}

apt_update_once() {
    if ((apt_updated)); then
        return 0
    fi
    apt_updated=1
    apt_get update
}

##### Package installation #####

install_tier() {
    local tier=$1
    local -a targets=() names=()
    local index

    for index in "${!pkg_name[@]}"; do
        if [[ ${pkg_tier[index]} != "$tier" || ${pkg_source[index]} != 'apt' ]]; then
            continue
        fi
        if package_present "$index"; then
            state_present+=("${pkg_name[index]}")
        else
            targets+=("$index")
            names+=("${pkg_name[index]}")
        fi
    done

    if ((${#names[@]} == 0)); then
        info "nothing to install, every $tier package is present"
        return 0
    fi

    # The dry run walks the same path so it prints the exact apt-get calls,
    # but run() turns them into 'would run:' lines.
    require_apt_privileges
    apt_update_once

    if ((dry_run)); then
        state_planned+=("${names[@]}")
        apt_get install -y --no-install-recommends "${names[@]}"
        return 0
    fi

    # One batch keeps the run short; if the batch fails, the packages are
    # retried one by one so the summary can name the ones that really failed.
    if ! apt_get install -y --no-install-recommends "${names[@]}"; then
        warn "installing $tier packages in one batch failed, retrying them one by one"
        local name
        for name in "${names[@]}"; do
            apt_get install -y --no-install-recommends "$name" || true
        done
    fi

    for index in "${targets[@]}"; do
        if package_present "$index"; then
            state_installed+=("${pkg_name[index]}")
        elif [[ $tier == 'required' ]]; then
            state_required_failures+=("${pkg_name[index]}")
        else
            state_optional_failures+=("${pkg_name[index]}")
        fi
    done
}

# Packages with source 'none' have no Debian 13 package and are deliberately
# not bootstrapped from anywhere else; they are used when they happen to exist.
report_unpackaged() {
    local index
    for index in "${!pkg_name[@]}"; do
        if [[ ${pkg_source[index]} != 'none' ]]; then
            continue
        fi
        if package_present "$index"; then
            state_present+=("${pkg_name[index]}")
        else
            note "${pkg_name[index]} has no Debian ${supported_version_id} package and is skipped; install it yourself if you want it."
        fi
    done
}

##### chezmoi #####

chezmoi_upstream_index() {
    local index
    for index in "${!pkg_name[@]}"; do
        if [[ ${pkg_name[index]} == 'chezmoi' ]]; then
            printf '%s' "$index"
            return 0
        fi
    done
    return 1
}

# Debian 13 has no chezmoi package, so the official upstream release is used:
# HTTPS only, into a private temporary directory, checked against the published
# SHA256 checksums and installed into ~/.local/bin instead of a system path.
# Nothing is piped into a shell.
install_chezmoi_from_upstream() {
    local arch machine
    machine="$(uname -m)"
    case $machine in
    x86_64) arch='amd64' ;;
    aarch64) arch='arm64' ;;
    *) die "no chezmoi release is selected for the architecture '$machine'. Install chezmoi manually (https://www.chezmoi.io/install/) and re-run with --skip-chezmoi-install." ;;
    esac

    local archive="chezmoi_${chezmoi_version}_linux_${arch}.tar.gz"
    local checksums="chezmoi_${chezmoi_version}_checksums.txt"
    local target_dir="$HOME/.local/bin"

    if ((dry_run)); then
        info "would download ${chezmoi_release_url}/${archive}, verify it against ${checksums} and install chezmoi into ${target_dir}"
        state_planned+=('chezmoi')
        return 0
    fi

    if ! command -v curl >/dev/null 2>&1; then
        die "chezmoi has to be downloaded, but curl was not found. Install curl ('apt-get install curl') and re-run install.sh."
    fi

    tmp_dir="$(mktemp -d)"

    local file
    for file in "$archive" "$checksums"; do
        if ! curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
            --output "$tmp_dir/$file" "${chezmoi_release_url}/${file}"; then
            die "downloading ${chezmoi_release_url}/${file} failed. Check the network connection, or install chezmoi yourself (https://www.chezmoi.io/install/) and re-run with --skip-chezmoi-install."
        fi
    done

    if ! (cd -- "$tmp_dir" && sha256sum --check --ignore-missing --status "$checksums"); then
        die "the SHA256 checksum of $archive does not match the published checksums, so the download was discarded. Nothing was installed."
    fi

    if ! tar -xzf "$tmp_dir/$archive" -C "$tmp_dir" chezmoi; then
        die "the downloaded archive $archive does not contain a chezmoi binary. Nothing was installed."
    fi

    mkdir -p -- "$target_dir"
    cp -- "$tmp_dir/chezmoi" "$target_dir/chezmoi"
    chmod 0755 -- "$target_dir/chezmoi"

    # The freshly installed binary is not in the PATH of this process yet.
    PATH="$target_dir:$PATH"
    export PATH

    state_installed+=('chezmoi')
    note "chezmoi ${chezmoi_version} was installed into ${target_dir}."
}

ensure_chezmoi() {
    if chezmoi_bin="$(command -v chezmoi 2>/dev/null)" && [[ -n $chezmoi_bin ]]; then
        info "chezmoi: $chezmoi_bin"
        state_present+=('chezmoi')
        return 0
    fi
    chezmoi_bin=''

    if ((skip_chezmoi_install)); then
        die "chezmoi was not found and --skip-chezmoi-install was given. Install chezmoi (https://www.chezmoi.io/install/) and re-run install.sh."
    fi

    local index
    if ! index="$(chezmoi_upstream_index)"; then
        die "chezmoi is missing from $package_file, so this run cannot bootstrap it."
    fi
    if [[ ${pkg_source[index]} != 'upstream' ]]; then
        die "$package_file declares chezmoi with source '${pkg_source[index]}', but install.sh can only bootstrap it from its upstream release."
    fi

    install_chezmoi_from_upstream

    if ((dry_run)); then
        return 0
    fi

    if ! chezmoi_bin="$(command -v chezmoi 2>/dev/null)" || [[ -z $chezmoi_bin ]]; then
        die "chezmoi is still not callable after the installation. Nothing was applied."
    fi
    info "chezmoi: $chezmoi_bin"
}

apply_dotfiles() {
    # 'init' writes the chezmoi configuration from home/.chezmoi.toml.tmpl so
    # that a plain 'chezmoi apply' keeps using this repository; '--apply'
    # updates the home directory. Both steps are idempotent.
    local -a args=(init --apply --source "$repo_root")

    if ((dry_run)); then
        info "would run: chezmoi ${args[*]}"
        return 0
    fi

    info "chezmoi ${args[*]}"
    local status=0
    "$chezmoi_bin" "${args[@]}" || status=$?
    if ((status != 0)); then
        printf '%s: chezmoi exited with code %s. Read the chezmoi output above; '\''chezmoi diff'\'' shows the pending changes and '\''chezmoi doctor'\'' checks the installation.\n' \
            "$script_name" "$status" >&2
        exit "$status"
    fi
}

##### Summary #####

print_list() {
    local label=$1
    shift
    if (($# > 0)); then
        printf '    %-18s %s\n' "$label" "$*"
    fi
}

print_summary() {
    step 'Summary'
    print_list 'would install:' "${state_planned[@]}"
    print_list 'installed:' "${state_installed[@]}"
    print_list 'already present:' "${state_present[@]}"
    print_list 'optional failures:' "${state_optional_failures[@]}"
    print_list 'required failures:' "${state_required_failures[@]}"

    local note_text
    for note_text in "${state_notes[@]}"; do
        printf '    %-18s %s\n' 'note:' "$note_text"
    done

    if ((${#state_optional_failures[@]} > 0)); then
        info 'the optional packages above are not installed; re-run install.sh or install them with apt-get later'
    fi
}

##### Main #####

main() {
    parse_args "$@"
    resolve_repo
    require_supported_distro
    load_packages

    step 'Checking prerequisites'
    info "distribution: ${distro_id} ${distro_version_id} ($(os_release_file))"
    info "repository:   $repo_root"
    info "source:       $source_dir"
    info "packages:     $package_file"
    if ((EUID == 0)); then
        info "user:         root (apt-get runs without sudo)"
    else
        info "user:         ${USER:-uid $EUID} (only apt-get is run with sudo)"
    fi
    if ((dry_run)); then
        info 'dry run:      nothing is installed, downloaded or written'
    fi

    if ((skip_packages)); then
        step 'Packages'
        note 'package installation skipped (--skip-packages).'
    else
        require_apt

        step 'Installing required packages'
        install_tier 'required'

        if ((skip_optional)); then
            step 'Optional packages'
            note 'optional CLI and TUI packages skipped (--skip-optional).'
        else
            step 'Installing optional packages'
            install_tier 'optional'
            report_unpackaged
        fi
    fi

    # Applying the dotfiles on top of a broken required set would leave a
    # half-working shell, so the run stops here instead.
    if ((${#state_required_failures[@]} > 0)); then
        print_summary
        die "the required packages ${state_required_failures[*]} could not be installed, so nothing was applied. Read the apt-get output above and re-run install.sh."
    fi

    step 'Checking chezmoi'
    ensure_chezmoi

    step 'Applying dotfiles with chezmoi'
    apply_dotfiles

    print_summary

    if ((dry_run)); then
        step 'Dry run complete, nothing was changed'
    else
        step 'Done, restart your shell to pick up the new configuration'
    fi
}

main "$@"
