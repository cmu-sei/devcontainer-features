#!/bin/bash
# Test against an existing, certificate-enabled organization base image.
set -euo pipefail
BASE_IMAGE="${1:?Usage: tools/test-base.sh BASE_IMAGE [feature ...]}"
shift
CLI="${DEVCONTAINER_CLI:-devcontainer}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
args=(features test --skip-scenarios --remote-user vscode --base-image "$BASE_IMAGE" --project-folder "$ROOT")
if [ "$#" -gt 0 ]; then
    args+=(--features "$@")
fi
exec "$CLI" "${args[@]}"
