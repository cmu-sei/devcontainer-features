#!/bin/bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
expected=$(jq -r '.options.version.default' /usr/local/share/org-features/codex/devcontainer-feature.json)
codex --version | grep -F "$expected"
bash /usr/local/share/org-features/codex/postcreate.sh
echo "Feature smoke test passed."
