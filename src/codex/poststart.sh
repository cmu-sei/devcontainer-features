#!/bin/bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/org-runtime.sh"
. "$(dirname "${BASH_SOURCE[0]}")/org-update.sh"

org_update_in_background codex codex update
