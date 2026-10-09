#!/bin/bash
set -euo pipefail
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$FEATURE_DIR/org-build.sh"
org_feature_init "$FEATURE_DIR" opencode
VERSION="${VERSION:-}"
[ -z "$VERSION" ] || [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][a-zA-Z0-9.-]+)?$ ]] || { echo "Use an exact tool version, or leave it empty for the latest release." >&2; exit 1; }
# Without a version, the upstream installer picks the latest release.
VERSION_ARG=""; [ -z "$VERSION" ] || VERSION_ARG="--version '$VERSION'"
# A pinned version opts out of the updates poststart.sh starts.
[ -z "$VERSION" ] || touch /usr/local/share/org-features/opencode/version-pinned
su - "$_REMOTE_USER" -s /bin/bash -c "set -euo pipefail; curl -fsSL https://opencode.ai/install | bash -s -- $VERSION_ARG"
USER_HOME="$(getent passwd "$_REMOTE_USER" | cut -d: -f6)"
install -d -o "$_REMOTE_USER" -g "$(id -gn "$_REMOTE_USER")" "$USER_HOME/.local/bin"
ln -sfn "$USER_HOME/.opencode/bin/opencode" "$USER_HOME/.local/bin/opencode"
