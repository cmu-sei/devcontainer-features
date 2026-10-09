#!/bin/bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
grok --version
bash /usr/local/share/org-features/grok/postcreate.sh
echo "Feature smoke test passed."
