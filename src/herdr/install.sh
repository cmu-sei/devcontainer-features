#!/bin/bash
set -euo pipefail
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$FEATURE_DIR/org-build.sh"
org_feature_init "$FEATURE_DIR" herdr
# The upstream installer installs the latest release to ~/.local/bin after checking its
# SHA-256 against the release manifest.
su - "$_REMOTE_USER" -s /bin/bash -c "set -euo pipefail; curl -fsSL https://herdr.dev/install.sh | sh"
