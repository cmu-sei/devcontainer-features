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

# Chowns a root-owned fresh volume; warns when ~/.data is not a mount.
org_prepare_data
mkdir -p "$HIST_DIR"

# Seed from the image's own history the first time only, so nothing typed during
# the build's first shell (or before this feature was added) is dropped.
for name in .bash_history .zsh_history; do
    if [ -s "$HOME/$name" ] && [ ! -L "$HOME/$name" ] && [ ! -s "$HIST_DIR/$name" ]; then
        cp "$HOME/$name" "$HIST_DIR/$name"
    fi
done
touch "$HIST_DIR/.bash_history" "$HIST_DIR/.zsh_history"
