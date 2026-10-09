#!/bin/bash
set -euo pipefail
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$FEATURE_DIR/org-build.sh"
org_feature_init "$FEATURE_DIR" pi
VERSION="${VERSION:-}"
[ -z "$VERSION" ] || [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][a-zA-Z0-9.-]+)?$ ]] || { echo "Use an exact tool version, or leave it empty for the latest release." >&2; exit 1; }
# Without a version, npm installs the latest release.
VERSION_ARG=""; [ -z "$VERSION" ] || VERSION_ARG="@$VERSION"
# A pinned version opts out of the updates poststart.sh starts.
[ -z "$VERSION" ] || touch /usr/local/share/org-features/pi/version-pinned
su - "$_REMOTE_USER" -s /bin/bash -c "
    set -euo pipefail
    . '${NVM_DIR:-/usr/local/share/nvm}/nvm.sh'
    export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
    npm install -g --ignore-scripts @earendil-works/pi-coding-agent$VERSION_ARG
"
