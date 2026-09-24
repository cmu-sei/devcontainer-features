#!/bin/bash
set -euo pipefail
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$FEATURE_DIR/org-build.sh"
org_feature_init "$FEATURE_DIR" shell-completions

COMMANDS="${COMMANDS:-auto}"
SHELLS="${SHELLS:-zsh,bash}"
[[ "$COMMANDS" =~ ^[A-Za-z0-9._,-]+$ ]] || { echo "shell-completions: invalid commands '$COMMANDS'." >&2; exit 1; }
[[ "$SHELLS" =~ ^((zsh|bash|fish),?)+$ ]] || { echo "shell-completions: shells must be zsh, bash, or fish." >&2; exit 1; }

# Options are build-time env only; persist them for the create-time rerun.
DEST=/usr/local/share/org-features/shell-completions
printf 'COMMANDS=%s\nSHELLS=%s\n' "$COMMANDS" "$SHELLS" > "$DEST/options.env"
ln -sfn "$DEST/install-completions.sh" /usr/local/bin/install-completions

# Tools installed by earlier features; later ones are caught on create. A failed
# generator only warns.
bash "$DEST/install-completions.sh" || true
