#!/usr/bin/env bash
#
# Bootstraps a Debian GNU/Linux 13 (trixie) machine from the takano536/dotfiles
# chezmoi source repository: installs the packages listed in packages/linux.tsv
# with apt, makes sure chezmoi is available and runs 'chezmoi init --apply' with
# the repository as the chezmoi source directory. Safe to run repeatedly.
#
# It works in two modes and decides which one applies on its own:
#
#   repository-local  started from a checkout, recognised by the .chezmoiroot
#                     file next to it. That checkout is used as it is and
#                     nothing is cloned.
#   bootstrap         started on its own, without a repository around it:
#                         curl -fsSL <raw url of install.sh> | bash
#                     The repository is then cloned into chezmoi's default
#                     source directory and the install.sh of the clone takes
#                     over the rest of the run.
#
#     bash ./install.sh [--dry-run] [--skip-packages] [--skip-optional]
#                       [--skip-chezmoi-install] [--help]
#
# Run it as the user the dotfiles belong to; 'sudo ./install.sh' and a root
# shell are refused. Only the apt calls are elevated, from inside the run.

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

# The repository this installer belongs to. An existing checkout is matched on
# owner and repository name; the host is compared separately, because the same
# repository is cloned over HTTPS, over SSH or through an ssh_config alias whose
# real host cannot be resolved from the URL.
readonly repo_slug='takano536/dotfiles'
readonly repo_host='github.com'
readonly repo_url="https://${repo_host}/${repo_slug}.git"
readonly repo_branch='main'

# A bootstrap run has to clone before it can read packages/linux.tsv, so these
# two packages are named here instead of in the package definition. git is a
# required package there as well; ca-certificates provides the HTTPS trust the
# clone needs.
readonly bootstrap_packages=(git ca-certificates)

# Set for the install.sh of a fresh clone, so a clone that still does not look
# like this repository fails instead of cloning again.
readonly bootstrap_marker='DOTFILES_BOOTSTRAP'

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
clone_tmp_dir=''
repo_root=''

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

# Both temporary directories are private to this run: the chezmoi download and
# an unfinished clone. Removing them can never touch the clone target, because
# a finished clone is moved out of clone_tmp_dir first.
cleanup_tmp_dirs() {
    local dir
    for dir in "${tmp_dir:-}" "${clone_tmp_dir:-}"; do
        if [[ -n $dir && -d $dir ]]; then
            rm -rf -- "$dir"
        fi
    done
}

trap cleanup_tmp_dirs EXIT
# An interrupted download or clone must not leave its temporary directory in
# the home directory of the user.
trap 'cleanup_tmp_dirs; exit 130' INT TERM HUP

usage() {
    cat <<EOF
Usage: bash ./install.sh [options]

Bootstraps Debian ${supported_version_id} from the ${repo_slug} chezmoi source
repository. Started from a checkout it uses that checkout; started on its own
it clones ${repo_url} into chezmoi's source directory first.

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

# The dotfiles belong to a normal user: 'sudo ./install.sh' would let chezmoi
# write into root's home directory and leave root-owned files behind. Only the
# apt-get calls are elevated, from inside the run.
reject_root() {
    if ((EUID == 0)); then
        die 'do not run install.sh as root or with sudo. Run it as the user who owns the dotfiles; the installer elevates only apt-get.'
    fi
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

# The directory of this script, or nothing when the script has no file of its
# own: 'curl ... | bash' leaves BASH_SOURCE[0] pointing at no readable file.
script_dir() {
    local source=${BASH_SOURCE[0]:-}
    if [[ -z $source || ! -f $source ]]; then
        return 0
    fi
    (cd -- "$(dirname -- "$source")" && pwd -P)
}

# .chezmoiroot is the marker of this repository. A checkout that has it but is
# missing other files is still this repository, and it has to fail with that
# problem instead of being replaced by a fresh clone somewhere else.
is_repo_dir() { [[ -f $1/.chezmoiroot ]]; }

# What a freshly cloned or adopted checkout has to provide before this run
# hands over to it.
is_complete_repo_dir() {
    [[ -f $1/.chezmoiroot && -f $1/install.sh && -f $1/packages/linux.tsv ]]
}

# Where a bootstrap run puts the repository: chezmoi's own default source
# directory, so that 'chezmoi apply' and 'chezmoi update' keep working without
# any extra configuration afterwards.
default_source_root() {
    printf '%s/chezmoi' "${XDG_DATA_HOME:-$HOME/.local/share}"
}

# Repository-local mode resolves the repository from the location of this
# script, not from the working directory, so 'bash /some/where/install.sh'
# works from anywhere. Everything else is a bootstrap run.
resolve_repo() {
    local dir
    dir="$(script_dir)"
    if [[ -n $dir ]] && is_repo_dir "$dir"; then
        repo_root=$dir
        return 0
    fi
    return 1
}

read_repo_layout() {
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
    # Read on every run, including --skip-packages, because it also declares
    # how chezmoi itself is bootstrapped.
    if [[ ! -f $package_file ]]; then
        die "the package list '$package_file' was not found. Check out the repository again."
    fi
}

##### Repository acquisition #####

# 'owner/repo', lower cased, from any of the URL forms git understands. Used to
# recognise an existing checkout of this repository without insisting on the
# exact URL it was cloned with.
remote_slug() {
    local url=${1%/}
    url=${url%.git}

    local name=${url##*/}
    local rest=${url%/*}
    # The owner is separated from the host by '/' in HTTPS URLs and by ':' in
    # SSH URLs, so both are accepted here.
    local owner=${rest##*[:/]}

    if [[ -z $name || -z $owner || $rest == "$url" ]]; then
        return 0
    fi
    printf '%s/%s' "${owner,,}" "${name,,}"
}

# The host of a remote URL, lower cased: 'https://host/owner/repo',
# 'ssh://git@host/owner/repo' and 'git@host:owner/repo' all resolve to 'host'.
# An ssh_config alias resolves to the alias, which is exactly what cannot be
# checked without reading the SSH configuration.
remote_host() {
    local rest=$1
    rest=${rest#*://}
    rest=${rest#*@}
    rest=${rest%%[:/]*}
    printf '%s' "${rest,,}"
}

# git is one of the required packages, but a bootstrap run needs it before it
# can read the package definition, so it is installed from here. The installer
# of the clone runs 'apt-get update' once more in its own process; that is the
# price of handing over, and only this path pays it.
ensure_git_for_clone() {
    if command -v git >/dev/null 2>&1; then
        info "git: $(command -v git)"
        return 0
    fi

    if ((skip_packages)); then
        die "git is needed to clone ${repo_url}, but --skip-packages was given. Install git ('sudo apt-get install git'), or clone the repository yourself and run its install.sh --skip-packages."
    fi

    info "git is not installed, installing ${bootstrap_packages[*]}"
    require_apt
    require_apt_privileges
    apt_update_once
    if ! apt_get install -y --no-install-recommends "${bootstrap_packages[@]}"; then
        die "installing ${bootstrap_packages[*]} failed, so ${repo_url} cannot be cloned. Read the apt-get output above, or clone the repository yourself and run its install.sh."
    fi
    if ! command -v git >/dev/null 2>&1; then
        die "git is still not callable after the installation, so ${repo_url} cannot be cloned. Nothing else was changed."
    fi
    info "git: $(command -v git)"
}

# A directory that is already there is never deleted, moved or reset: it may be
# the user's own checkout with unpushed work. Returns 0 when it can be used as
# it is, 1 when it is empty and can be cloned into, and fails the run in every
# other case, with the way out in the message.
adopt_existing_checkout() {
    local dir=$1

    if [[ ! -d $dir ]]; then
        die "'$dir' exists but is not a directory, so the dotfiles cannot be cloned there. Move it aside, or clone the repository yourself and run its install.sh."
    fi

    local -a entries=()
    shopt -s nullglob dotglob
    entries=("$dir"/*)
    shopt -u nullglob dotglob
    if ((${#entries[@]} == 0)); then
        return 1
    fi

    if ! is_complete_repo_dir "$dir"; then
        die "'$dir' already exists and does not contain this dotfiles repository (.chezmoiroot, install.sh and packages/linux.tsv). Nothing was changed. Inspect it, then move it aside and re-run, or run install.sh from your own checkout."
    fi

    # Without git the checkout cannot be verified, but its layout already
    # matches; the run continues and reports that it could not check.
    if ! command -v git >/dev/null 2>&1; then
        note "the checkout in $dir was not verified because git is not installed yet."
        return 0
    fi

    if ! git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
        die "'$dir' contains the dotfiles but is not a git repository, so it cannot be updated later. Move it aside and re-run to get a clone, or run install.sh from your own checkout."
    fi

    local origin slug host
    origin="$(git -C "$dir" remote get-url origin 2>/dev/null || true)"
    slug="$(remote_slug "$origin")"
    if [[ $slug != "$repo_slug" ]]; then
        die "'$dir' is a checkout of '${origin:-an unknown remote}', not of ${repo_slug}. Nothing was changed. Point 'origin' at ${repo_url}, or move that directory aside and re-run."
    fi

    info "using the existing checkout in $dir"
    # Nothing is fetched or reset here, so a host that only looks like the
    # expected one cannot change the checkout; it is reported instead of
    # resolving the SSH configuration to find out what the alias points at.
    host="$(remote_host "$origin")"
    if [[ $host != "$repo_host" ]]; then
        note "the origin of $dir is '${origin}', which names ${repo_slug} but not ${repo_host}; it is used as it is, on the assumption that '${host}' is an ssh_config alias for ${repo_host}."
    fi
    if [[ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]]; then
        note "the checkout in $dir has uncommitted changes; nothing was pulled and they were left untouched."
    fi
    return 0
}

# Cloned into a private temporary directory next to the target and moved into
# place afterwards, so an interrupted clone leaves nothing behind at the target
# and an existing directory is never overwritten.
clone_repo() {
    local target=$1 parent
    parent="$(dirname -- "$target")"

    mkdir -p -- "$parent"
    if ! clone_tmp_dir="$(mktemp -d -- "$parent/.dotfiles-clone.XXXXXX")"; then
        die "a temporary directory for the clone could not be created in '$parent'. Nothing was changed."
    fi

    info "git clone ${repo_url} (branch ${repo_branch})"
    # GIT_TERMINAL_PROMPT keeps git from asking for credentials: this is a
    # public repository over HTTPS, and a bootstrap run may have no terminal.
    if ! GIT_TERMINAL_PROMPT=0 git clone --branch "$repo_branch" -- "$repo_url" "$clone_tmp_dir/repo"; then
        die "cloning ${repo_url} failed and '$target' was not created. Check the network connection and re-run, or clone the repository yourself and run its install.sh."
    fi
    if ! is_complete_repo_dir "$clone_tmp_dir/repo"; then
        die "the clone of ${repo_url} does not contain .chezmoiroot, install.sh and packages/linux.tsv, so it was discarded. Nothing was changed."
    fi

    # An empty directory at the target is what 'mkdir -p' or an interrupted
    # attempt leaves behind, and it holds nothing that could be lost.
    if [[ -d $target ]]; then
        rmdir -- "$target" 2>/dev/null || true
    fi
    if [[ -e $target ]]; then
        die "'$target' appeared while cloning, so the clone was discarded instead of overwriting it. Re-run install.sh."
    fi
    if ! mv -- "$clone_tmp_dir/repo" "$target"; then
        die "moving the clone to '$target' failed. The clone was discarded and nothing was changed."
    fi

    rm -rf -- "$clone_tmp_dir"
    clone_tmp_dir=''
    note "${repo_slug} was cloned into $target."
}

acquire_repo() {
    if [[ -n ${!bootstrap_marker:-} ]]; then
        die "the clone this installer handed over to does not look like ${repo_slug} either, so the bootstrap stopped instead of cloning again. Clone ${repo_url} yourself and run its install.sh."
    fi

    local target
    target="$(default_source_root)"

    if [[ -e $target ]] && adopt_existing_checkout "$target"; then
        repo_root=$target
        return 0
    fi

    if ((dry_run)); then
        info "would clone ${repo_url} (branch ${repo_branch}) into ${target}"
        info "the full plan needs the repository; clone it and run 'bash install.sh --dry-run' inside the clone"
        return 1
    fi

    ensure_git_for_clone
    clone_repo "$target"
    repo_root=$target
}

# The repository is the source of truth for the installer, so the rest of the
# run is done by the install.sh of the clone instead of by this copy, which may
# be older or may have been fetched from anywhere.
hand_over_to_repo_installer() {
    local installer="$repo_root/install.sh"
    if [[ ! -f $installer ]]; then
        die "'$installer' is missing, so the run cannot continue. Nothing was applied."
    fi

    step "Running the installer of $repo_root"
    export "$bootstrap_marker=1"
    exec "$BASH" -- "$installer" "$@"
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
        # A bootstrap run has no repository yet, so the hint names the remote.
        local chezmoi_hint="chezmoi init --apply '${repo_url}'"
        if [[ -n $repo_root ]]; then
            chezmoi_hint="chezmoi init --apply --source '${repo_root}'"
        fi
        die "this installer supports Debian GNU/Linux ${supported_version_id} (trixie) only, but ${file} reports ID='${distro_id}' VERSION_ID='${distro_version_id}'. Nothing was installed. On another system, install chezmoi yourself and run: ${chezmoi_hint}"
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

# apt is the only elevated part of the run, so sudo is resolved lazily: a
# machine that already has every package needs no sudo at all.
require_apt_privileges() {
    if command -v sudo >/dev/null 2>&1; then
        apt_prefix=(sudo)
        return 0
    fi
    if ((dry_run)); then
        note 'sudo is not installed; a real run would need it for apt-get.'
        return 0
    fi
    die "packages have to be installed, but sudo was not found. Install sudo (https://wiki.debian.org/sudo) and try again."
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

# 'curl ... | bash' leaves the rest of this script on stdin, where sudo would
# read it as a password. Reopening stdin is only safe once bash has read the
# whole script, which is the case here: main is the last command of the file.
detach_script_from_stdin() {
    if [[ -t 0 ]]; then
        return 0
    fi
    if (: </dev/tty) 2>/dev/null; then
        exec </dev/tty
    else
        exec </dev/null
    fi
}

# A bootstrap run only prepares the repository and then hands over, so this is
# the whole run for it. Everything after it needs the repository.
bootstrap_phase() {
    step 'Fetching the dotfiles repository'
    if ! acquire_repo; then
        step 'Dry run complete, nothing was cloned'
        exit 0
    fi
    hand_over_to_repo_installer "$@"
}

main() {
    parse_args "$@"
    reject_root
    detach_script_from_stdin

    local bootstrap=0
    resolve_repo || bootstrap=1
    require_supported_distro
    if ((bootstrap)); then
        bootstrap_phase "$@"
    fi

    read_repo_layout
    load_packages

    step 'Checking prerequisites'
    info "distribution: ${distro_id} ${distro_version_id} ($(os_release_file))"
    info "repository:   $repo_root"
    info "source:       $source_dir"
    info "packages:     $package_file"
    info "user:         ${USER:-uid $EUID} (only apt-get is run with sudo)"
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
