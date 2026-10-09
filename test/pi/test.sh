#!/bin/bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
pi --version
bash /usr/local/share/org-features/pi/postcreate.sh
echo "Feature smoke test passed."
