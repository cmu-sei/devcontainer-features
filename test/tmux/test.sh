#!/bin/bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
tmux -V && test -f "$HOME/.tmux.conf"
echo "Feature smoke test passed."
