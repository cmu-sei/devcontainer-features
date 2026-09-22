#!/bin/bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
expected=$(jq -r '.options.version.default' /usr/local/share/org-features/opencode/devcontainer-feature.json)
opencode --version | grep -F "$expected"
bash /usr/local/share/org-features/opencode/postcreate.sh
echo "Feature smoke test passed."
