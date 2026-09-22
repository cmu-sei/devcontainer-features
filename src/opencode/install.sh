#!/bin/bash
set -euo pipefail
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$FEATURE_DIR/org-build.sh"
org_feature_init "$FEATURE_DIR" opencode
VERSION="${VERSION:-1.18.32}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][a-zA-Z0-9.-]+)?$ ]] || { echo "Use an exact tool version." >&2; exit 1; }
su - "$_REMOTE_USER" -s /bin/bash -c "set -euo pipefail; curl -fsSL https://opencode.ai/install | bash -s -- --version '$VERSION'"
USER_HOME="$(getent passwd "$_REMOTE_USER" | cut -d: -f6)"
install -d -o "$_REMOTE_USER" -g "$(id -gn "$_REMOTE_USER")" "$USER_HOME/.local/bin"
ln -sfn "$USER_HOME/.opencode/bin/opencode" "$USER_HOME/.local/bin/opencode"
