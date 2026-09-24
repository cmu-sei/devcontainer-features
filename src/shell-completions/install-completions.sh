#!/bin/bash
# Usage: install-completions [cli...]
# Writes completions for each CLI into the system completion directories. No
# arguments means the feature's configured `commands` option. Missing CLIs are
# skipped; a CLI whose generator fails only warns. SHELL_COMPLETIONS_PREFIX
# (default /usr/local/share) relocates the output, e.g. for tests.
set -uo pipefail

OPTIONS="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/options.env"
PREFIX="${SHELL_COMPLETIONS_PREFIX:-/usr/local/share}"
AUTO=(just kubectl helm minikube uv docker gh rg fd codex)

# Read without sourcing; `options.env` is data.
option() { [ -f "$OPTIONS" ] || return 0; sed -n "s/^$1=//p" "$OPTIONS" | tail -n 1; }
SHELLS="$(option SHELLS)"; SHELLS="${SHELLS:-zsh,bash}"

generate() {  # cli shell
    case "$1" in
        just) just --completions "$2" ;;
        uv)   uv generate-shell-completion "$2" ;;
        gh)   gh completion -s "$2" ;;
        rg)   rg --generate "complete-$2" ;;
        fd)   fd --gen-completions "$2" ;;
        *)    "$1" completion "$2" ;;  # cobra/clap convention
    esac
}

target() {  # cli shell
    case "$2" in
        zsh)  echo "$PREFIX/zsh/site-functions/_$1" ;;
        bash) echo "$PREFIX/bash-completion/completions/$1" ;;
        fish) echo "$PREFIX/fish/vendor_completions.d/$1.fish" ;;
    esac
}

# Root at build time; on create, sudo only when the target is not writable.
put() {  # source destination
    if mkdir -p "$(dirname "$2")" 2>/dev/null && [ -w "$(dirname "$2")" ]; then
        install -m 644 "$1" "$2"
    elif [ "$(id -u)" != 0 ]; then
        sudo -n install -D -m 644 "$1" "$2"
    else
        return 1
    fi
}

if [ "$#" -gt 0 ]; then
    CLIS=("$@")
else
    COMMANDS="$(option COMMANDS)"
    if [ -z "$COMMANDS" ] || [ "$COMMANDS" = auto ]; then
        CLIS=("${AUTO[@]}")
    else
        IFS=, read -ra CLIS <<< "$COMMANDS"
    fi
fi
IFS=, read -ra SHELL_LIST <<< "$SHELLS"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
status=0
for cli in "${CLIS[@]}"; do
    command -v "$cli" >/dev/null 2>&1 || continue
    written=()
    for shell in "${SHELL_LIST[@]}"; do
        dest="$(target "$cli" "$shell")"
        # stdin closed: a generator must never wait on a prompt during a build.
        if ! generate "$cli" "$shell" > "$tmp" 2>/dev/null < /dev/null || [ ! -s "$tmp" ]; then
            echo "shell-completions: no $shell completion from '$cli'." >&2
            status=1
            continue
        fi
        # A zsh file without #compdef is ignored by compinit; treat it as a failure.
        if [ "$shell" = zsh ] && ! head -n 5 "$tmp" | grep -q '^#compdef'; then
            echo "shell-completions: '$cli' did not emit a zsh completion." >&2
            status=1
            continue
        fi
        if put "$tmp" "$dest"; then
            written+=("$shell")
        else
            echo "shell-completions: cannot write $dest." >&2
            status=1
        fi
    done
    [ "${#written[@]}" -gt 0 ] && echo "shell-completions: $cli (${written[*]})"
done
exit "$status"
