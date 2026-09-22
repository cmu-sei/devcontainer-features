#!/bin/bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
expected=$(jq -r '.options.version.default' /usr/local/share/org-features/grok/devcontainer-feature.json)
grok --version | grep -F "$expected"
bash /usr/local/share/org-features/grok/postcreate.sh
echo "Feature smoke test passed."
