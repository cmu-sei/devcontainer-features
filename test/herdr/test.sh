#!/bin/bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
herdr --version
bash /usr/local/share/org-features/herdr/postcreate.sh
echo "Feature smoke test passed."
