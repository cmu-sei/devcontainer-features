#!/bin/bash
## Create the history directory on the persistent volume
set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/org-runtime.sh"

OPTIONS="$(dirname "${BASH_SOURCE[0]}")/options.env"
option() { [ -f "$OPTIONS" ] || return 0; sed -n "s/^$1=//p" "$OPTIONS" | tail -n 1; }
DIRECTORY="$(option DIRECTORY)"
DIRECTORY="${DIRECTORY:-.data/shell-history}"
case "$DIRECTORY" in
    /*) HIST_DIR="$DIRECTORY" ;;
    *)  HIST_DIR="$HOME/$DIRECTORY" ;;
esac

# Keep the shared volume setup for the default layout. Custom directories may
# instead live on a separate root-owned mount; prepare that destination itself.
case "$HIST_DIR" in
    "$HOME/.data"|"$HOME/.data/"*) org_prepare_data ;;
esac
if ! mkdir -p "$HIST_DIR" 2>/dev/null || [ ! -w "$HIST_DIR" ]; then
    if [ "$(id -u)" = 0 ]; then
        install -d -m 755 -o "$(id -u)" -g "$(id -g)" "$HIST_DIR"
    else
        sudo -n install -d -m 755 -o "$(id -u)" -g "$(id -g)" "$HIST_DIR"
    fi
fi

# Seed from the image's own history the first time only, so nothing typed during
# the build's first shell (or before this feature was added) is dropped.
for name in .bash_history .zsh_history; do
    if [ -s "$HOME/$name" ] && [ ! -L "$HOME/$name" ] && [ ! -e "$HIST_DIR/$name" ] && [ ! -L "$HIST_DIR/$name" ]; then
        cp "$HOME/$name" "$HIST_DIR/$name"
    fi
done
touch "$HIST_DIR/.bash_history" "$HIST_DIR/.zsh_history"
