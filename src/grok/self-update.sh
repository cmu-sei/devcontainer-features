#!/bin/bash
# Run by poststart.sh in the background: updates Grok, then deletes downloaded releases
# that no ~/.grok/bin link uses, since each update leaves another binary on the volume.
# Paths are compared resolved because ~/.grok itself links to the volume.
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"

grok update
status=$?

keep=()
for link in "$HOME"/.grok/bin/*; do
    [ -L "$link" ] && keep+=("$(readlink -f "$link")")
done
for file in "$HOME"/.grok/downloads/grok-*; do
    [ -f "$file" ] || continue
    used=false
    for target in "${keep[@]}"; do
        [ "$target" = "$(readlink -f "$file")" ] && used=true
    done
    if [ "$used" = false ]; then
        echo "Removing unused $file"
        rm -f "$file"
    fi
done
exit "$status"
