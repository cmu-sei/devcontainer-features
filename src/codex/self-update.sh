#!/bin/bash
# Run by poststart.sh in the background: updates Codex, then deletes installed releases
# that neither the current link nor a running process uses, since each update leaves
# another release on the volume. A running codex still executes bwrap and rg from its
# release, so a session started before the update finished keeps its release.
# Paths are compared resolved because ~/.codex itself links to the volume.
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"

codex update
status=$?

root="$HOME/.codex/packages/standalone"
keep=()
[ -L "$root/current" ] && keep+=("$(readlink -f "$root/current")")
for exe in /proc/[0-9]*/exe; do
    target="$(readlink -f "$exe" 2>/dev/null)" && keep+=("$target")
done
releases="$(readlink -f "$root/releases")"
for release in "$root"/releases/*; do
    # Only real release directories; a link could point at user data outside releases/.
    [ -d "$release" ] && [ ! -L "$release" ] || continue
    release="$(readlink -f "$release")"
    [ "${release%/*}" = "$releases" ] || continue
    used=false
    for target in "${keep[@]}"; do
        [[ "$target" = "$release" || "$target" = "$release"/* ]] && used=true
    done
    if [ "$used" = false ]; then
        echo "Removing unused $release"
        rm -rf "$release"
    fi
done
exit "$status"
