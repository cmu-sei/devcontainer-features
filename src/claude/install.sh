#!/bin/bash
set -euo pipefail
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$FEATURE_DIR/org-build.sh"
org_feature_init "$FEATURE_DIR" claude
VERSION="${VERSION:-2.1.280}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][a-zA-Z0-9.-]+)?$ ]] || { echo "Use an exact tool version." >&2; exit 1; }
su - "$_REMOTE_USER" -s /bin/bash -c "set -euo pipefail; curl -fsSL https://claude.ai/install.sh | bash -s -- '$VERSION'"
