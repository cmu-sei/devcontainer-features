#!/bin/bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
expected=$(jq -r '.version' /usr/local/share/org-features/herdr/release.json)
herdr --version | grep -F "$expected"
bash /usr/local/share/org-features/herdr/postcreate.sh
echo "Feature smoke test passed."
