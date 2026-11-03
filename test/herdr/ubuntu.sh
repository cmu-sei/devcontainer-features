#!/bin/bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
herdr --version
# The agent hooks that `herdr integration install` writes import these.
python3 -c "import json, socket"
bash /usr/local/share/org-features/herdr/postcreate.sh
echo "Feature smoke test passed."
