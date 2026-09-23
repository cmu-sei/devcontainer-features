#!/bin/bash
set -euo pipefail

FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$FEATURE_DIR/org-build.sh"

# Add the SEI root CAs and the Zscaler root to the system trust store.
#
# Done BEFORE org_feature_init: that may apt-get missing tools, and behind Zscaler's TLS
# inspection the download only succeeds once these roots are trusted. The consumer's
# devcontainer.json must also list this feature first in overrideFeatureInstallOrder, since
# the CLI otherwise schedules features like node and uv (which download too) ahead of it.
if [ "$(id -u)" != 0 ]; then
    echo "Feature installers must run as root during the image build." >&2
    exit 1
fi
if ! command -v update-ca-certificates >/dev/null; then
    echo "sei-certs needs the ca-certificates package in the base image." >&2
    exit 1
fi
install -d -m 755 /usr/local/share/ca-certificates/custom
install -m 644 "$FEATURE_DIR"/*.crt /usr/local/share/ca-certificates/custom/
update-ca-certificates

org_feature_init "$FEATURE_DIR" "sei-certs"
