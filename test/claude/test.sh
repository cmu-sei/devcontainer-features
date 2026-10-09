#!/bin/bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
claude --version
bash /usr/local/share/org-features/claude/postcreate.sh
echo "Feature smoke test passed."
