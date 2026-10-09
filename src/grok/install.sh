#!/bin/bash
set -euo pipefail
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$FEATURE_DIR/org-build.sh"
org_feature_init "$FEATURE_DIR" grok
VERSION="${VERSION:-}"
[ -z "$VERSION" ] || [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][a-zA-Z0-9.-]+)?$ ]] || { echo "Use an exact tool version, or leave it empty for the latest release." >&2; exit 1; }
# Without a version, the upstream installer picks the latest release.
VERSION_ARG=""; [ -z "$VERSION" ] || VERSION_ARG="'$VERSION'"
# A pinned version opts out of the updates poststart.sh starts.
[ -z "$VERSION" ] || touch /usr/local/share/org-features/grok/version-pinned
install -m 755 "$FEATURE_DIR/bedrock-api-key" /usr/local/bin/bedrock-api-key
su - "$_REMOTE_USER" -s /bin/bash -c "
    set -euo pipefail
    export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    curl -fsSL https://x.ai/cli/install.sh | bash -s -- $VERSION_ARG
    uv venv --clear --python-preference only-system \"\$HOME/.local/bedrock-token-venv\"
    uv pip install --python \"\$HOME/.local/bedrock-token-venv/bin/python\" aws-bedrock-token-generator==1.1.0
"
# Copy the executable out of the persisted ~/.grok directory: postcreate.sh points
# ~/.grok/bin/grok at this copy on every create, so an old download on the volume never
# hides a newer image, and `grok update` then repoints it at its own download.
USER_HOME="$(getent passwd "$_REMOTE_USER" | cut -d: -f6)"
install -d /usr/local/lib/org-features/grok
install -m 755 "$(readlink -f "$USER_HOME/.grok/bin/grok")" /usr/local/lib/org-features/grok/grok
install -d -o "$_REMOTE_USER" -g "$(id -gn "$_REMOTE_USER")" "$USER_HOME/.local/bin"
ln -sfn "$USER_HOME/.grok/bin/grok" "$USER_HOME/.local/bin/grok"
