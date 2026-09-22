#!/bin/bash
set -euo pipefail
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$FEATURE_DIR/org-build.sh"
org_feature_init "$FEATURE_DIR" herdr
case "$(uname -m)" in
    x86_64) platform=linux-x86_64 ;;
    aarch64) platform=linux-aarch64 ;;
    *) echo "Unsupported architecture" >&2; exit 1 ;;
esac
url=$(jq -er --arg p "$platform" '.assets[$p]' "$FEATURE_DIR/release.json")
checksum=$(jq -er --arg p "$platform" '.sha256[$p]' "$FEATURE_DIR/release.json")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL --retry 3 "$url" -o "$tmp/herdr"
printf '%s  %s\n' "$checksum" "$tmp/herdr" | sha256sum -c -
USER_HOME="$(getent passwd "$_REMOTE_USER" | cut -d: -f6)"
install -d -o "$_REMOTE_USER" -g "$(id -gn "$_REMOTE_USER")" "$USER_HOME/.local/bin"
install -m 755 -o "$_REMOTE_USER" -g "$(id -gn "$_REMOTE_USER")" "$tmp/herdr" "$USER_HOME/.local/bin/herdr"
