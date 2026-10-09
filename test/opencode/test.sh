#!/bin/bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
opencode --version
bash /usr/local/share/org-features/opencode/postcreate.sh
echo "Feature smoke test passed."
