#!/bin/bash
set -euo pipefail
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$FEATURE_DIR/org-build.sh"
org_feature_init "$FEATURE_DIR" codex
VERSION="${VERSION:-}"
[ -z "$VERSION" ] || [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][a-zA-Z0-9.-]+)?$ ]] || { echo "Use an exact tool version, or leave it empty for the latest release." >&2; exit 1; }
# Without a version, the upstream installer picks the latest release.
VERSION_ARG=""; [ -z "$VERSION" ] || VERSION_ARG="--release '$VERSION'"
# A pinned version opts out of the updates poststart.sh starts.
[ -z "$VERSION" ] || touch /usr/local/share/org-features/codex/version-pinned
# Use the same Codex home at build and runtime so the CLI can detect its updater.
su - "$_REMOTE_USER" -s /bin/bash -c "
    set -euo pipefail
    curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh -s -- $VERSION_ARG
"
