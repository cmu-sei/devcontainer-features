#!/bin/bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
test -f "$HOME/.zsh/pure/pure.zsh"
echo "Feature smoke test passed."
