#!/bin/bash
set -euo pipefail

FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$FEATURE_DIR/org-build.sh"

# Add every root CA certificate in FOLDER to the system trust store.
#
# FOLDER is a path inside the image: an installer only sees the image and its own package,
# never the project, so the base Dockerfile copies the certificates in first (see the
# README). Done BEFORE org_feature_init, which may apt-get missing tools: behind a TLS-
# inspecting proxy that download only succeeds once its root is trusted. The consumer's
# devcontainer.json should also list this feature first in overrideFeatureInstallOrder,
# since the CLI otherwise schedules features like node and uv (which download too) ahead
# of it.
FOLDER="${FOLDER:-/usr/local/share/custom-certs}"
if [ "$(id -u)" != 0 ]; then
    echo "Feature installers must run as root during the image build." >&2
    exit 1
fi
if ! command -v update-ca-certificates >/dev/null; then
    echo "custom-certs needs the ca-certificates package in the base image." >&2
    exit 1
fi

# No certificates is a warning, not a failure: a project that needs none (or is built
# off the proxy) keeps the feature listed and still builds.
shopt -s nullglob
certs=("$FOLDER"/*.crt)
if [ "${#certs[@]}" -eq 0 ]; then
    echo "custom-certs: no *.crt files in '$FOLDER'; nothing added to the trust store." >&2
else
    install -d -m 755 /usr/local/share/ca-certificates/custom
    install -m 644 "${certs[@]}" /usr/local/share/ca-certificates/custom/
    update-ca-certificates
    echo "custom-certs: trusted ${#certs[@]} certificate(s) from '$FOLDER'."
fi

org_feature_init "$FEATURE_DIR" "custom-certs"
