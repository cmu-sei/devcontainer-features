#!/bin/bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
expected=$(jq -r '.options.version.default' /usr/local/share/org-features/oh-my-logo/devcontainer-feature.json)
npm list -g --depth 0 oh-my-logo | grep -F "oh-my-logo@$expected"
echo "Feature smoke test passed."
