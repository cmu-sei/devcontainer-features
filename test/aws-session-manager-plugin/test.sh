#!/bin/bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
aws --version
expected=$(jq -r '.version' /usr/local/share/org-features/aws-session-manager-plugin/release.json)
session-manager-plugin --version | grep -F "$expected"
echo "Feature smoke test passed."
