#!/bin/bash
set -euo pipefail
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$FEATURE_DIR/org-build.sh"
org_feature_init "$FEATURE_DIR" grok
VERSION="${VERSION:-1.0.40}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][a-zA-Z0-9.-]+)?$ ]] || { echo "Use an exact tool version." >&2; exit 1; }
install -m 755 "$FEATURE_DIR/bedrock-api-key" /usr/local/bin/bedrock-api-key
su - "$_REMOTE_USER" -s /bin/bash -c "
    set -euo pipefail
    export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    curl -fsSL https://x.ai/cli/install.sh | bash -s -- '$VERSION'
    uv venv --clear --python-preference only-system \"\$HOME/.local/bedrock-token-venv\"
    uv pip install --python \"\$HOME/.local/bedrock-token-venv/bin/python\" aws-bedrock-token-generator==1.1.0
"
# Copy the executable out of the persisted ~/.grok directory.
USER_HOME="$(getent passwd "$_REMOTE_USER" | cut -d: -f6)"
install -d /usr/local/lib/org-features/grok
install -m 755 "$(readlink -f "$USER_HOME/.grok/bin/grok")" /usr/local/lib/org-features/grok/grok
install -d -o "$_REMOTE_USER" -g "$(id -gn "$_REMOTE_USER")" "$USER_HOME/.local/bin"
ln -sfn /usr/local/lib/org-features/grok/grok "$USER_HOME/.local/bin/grok"
