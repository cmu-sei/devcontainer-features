#!/bin/bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
expected=$(jq -r '.options.version.default' /usr/local/share/org-features/claude/devcontainer-feature.json)
claude --version | grep -F "$expected"
bash /usr/local/share/org-features/claude/postcreate.sh
echo "Feature smoke test passed."
