#!/bin/bash
set -euo pipefail
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$FEATURE_DIR/org-build.sh"
org_feature_init "$FEATURE_DIR" claude
VERSION="${VERSION:-}"
[ -z "$VERSION" ] || [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][a-zA-Z0-9.-]+)?$ ]] || { echo "Use an exact tool version, or leave it empty for the latest release." >&2; exit 1; }
# Without a version, the upstream installer picks its default (current) release.
VERSION_ARG=""; [ -z "$VERSION" ] || VERSION_ARG="'$VERSION'"
# A pinned version opts out of the updates poststart.sh starts.
[ -z "$VERSION" ] || touch /usr/local/share/org-features/claude/version-pinned
su - "$_REMOTE_USER" -s /bin/bash -c "set -euo pipefail; curl -fsSL https://claude.ai/install.sh | bash -s -- $VERSION_ARG"
# Recorded for postcreate.sh, which turns it into Claude Code settings: a feature's
# containerEnv is static and cannot follow an option.
if [ "${BEDROCK:-false}" = true ]; then
    touch /usr/local/share/org-features/claude/bedrock-enabled
fi
