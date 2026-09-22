#!/bin/bash
set -euo pipefail
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$FEATURE_DIR/org-build.sh"
org_feature_init "$FEATURE_DIR" codex
VERSION="${VERSION:-0.155.1}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][a-zA-Z0-9.-]+)?$ ]] || { echo "Use an exact tool version." >&2; exit 1; }
# Keep executable packages outside ~/.codex, which the runtime persists on a volume.
su - "$_REMOTE_USER" -s /bin/bash -c "
    set -euo pipefail
    curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_HOME=\"\$HOME/.local/share/codex-install\" CODEX_NON_INTERACTIVE=1 sh -s -- --release '$VERSION'
"
