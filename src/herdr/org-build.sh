#!/bin/bash
# Shared build setup. Each feature carries its own copy for OCI packaging.
org_feature_init() {
    local source_dir="$1" feature="$2"
    if [ "$(id -u)" != 0 ]; then
        echo "Feature installers must run as root during the image build." >&2
        exit 1
    fi
    local distro
    distro=$(. /etc/os-release; printf '%s' "$ID")
    case "$distro" in
        debian|ubuntu) ;;
        *) echo "org-features supports Debian and Ubuntu bases; got $distro." >&2; exit 1 ;;
    esac
    : "${_REMOTE_USER:=root}"
    export _REMOTE_USER
    # install -d only applies ownership to its last component. Create both parents
    # explicitly so a feature installed first cannot leave ~/.local owned by root.
    local user_home user_group
    user_home="$(getent passwd "$_REMOTE_USER" | cut -d: -f6)"
    user_group="$(id -gn "$_REMOTE_USER")"
    install -d -m 755 -o "$_REMOTE_USER" -g "$user_group" \
        "$user_home/.local" "$user_home/.local/bin"
    local missing=() command
    for command in curl jq git sudo zsh; do
        command -v "$command" >/dev/null || missing+=("$command")
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}" ca-certificates
    fi
    local destination="/usr/local/share/org-features/$feature"
    install -d -m 755 "$destination"
    cp -a "$source_dir/." "$destination/"
    find "$destination" -type d -exec chmod 755 {} +
    find "$destination" -type f -exec chmod 644 {} +
    find "$destination" -name '*.sh' -exec chmod 755 {} +
}
