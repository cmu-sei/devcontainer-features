#!/bin/bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
aws --version
bash /usr/local/share/org-features/bedrock/postcreate.sh
echo "Feature smoke test passed."
