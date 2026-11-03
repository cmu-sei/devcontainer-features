#!/bin/bash
set -euo pipefail
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$FEATURE_DIR/org-build.sh"
org_feature_init "$FEATURE_DIR" herdr
# The agent hooks from `herdr integration install` run python3 and import json and socket.
# Some bases ship only python3-minimal, which lacks them; install the full standard library
# unless a complete Python is already present (from the base or the python feature).
if ! python3 -c "import json, socket" >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends python3
fi
# The upstream installer installs the latest release to ~/.local/bin after checking its
# SHA-256 against the release manifest.
su - "$_REMOTE_USER" -s /bin/bash -c "set -euo pipefail; curl -fsSL https://herdr.dev/install.sh | sh"
