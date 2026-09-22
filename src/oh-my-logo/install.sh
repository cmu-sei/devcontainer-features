#!/bin/bash
set -euo pipefail
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$FEATURE_DIR/org-build.sh"
org_feature_init "$FEATURE_DIR" oh-my-logo
VERSION="${VERSION:-0.5.0}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][a-zA-Z0-9.-]+)?$ ]] || { echo "Use an exact tool version." >&2; exit 1; }
su - "$_REMOTE_USER" -s /bin/bash -c "
    set -euo pipefail
    . '${NVM_DIR:-/usr/local/share/nvm}/nvm.sh'
    export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
    npm install -g --ignore-scripts oh-my-logo@$VERSION
"
