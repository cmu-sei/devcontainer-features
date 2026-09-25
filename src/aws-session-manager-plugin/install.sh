#!/bin/bash
set -euo pipefail
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$FEATURE_DIR/org-build.sh"
org_feature_init "$FEATURE_DIR" aws-session-manager-plugin
arch=$(dpkg --print-architecture)
if ! url=$(jq -er --arg a "$arch" '.assets[$a]' "$FEATURE_DIR/release.json"); then
    echo "No Session Manager plugin for architecture $arch" >&2
    exit 1
fi
checksum=$(jq -er --arg a "$arch" '.sha256[$a]' "$FEATURE_DIR/release.json")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL --retry 3 "$url" -o "$tmp/session-manager-plugin.deb"
printf '%s  %s\n' "$checksum" "$tmp/session-manager-plugin.deb" | sha256sum -c -
# The package's postinst links /usr/local/bin/session-manager-plugin.
dpkg -i "$tmp/session-manager-plugin.deb"
session-manager-plugin --version
