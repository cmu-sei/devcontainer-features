#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA="$HOME/.data"
sudo chown "$(id -u):$(id -g)" "$DATA"

# Install find-skills
echo "Installing find-skills skill..."
npx -y skills@latest add vercel-labs/skills -s find-skills \
    -g --copy -a claude-code -a codex -a opencode -a pi -y || echo "postcreate: find-skills install failed (continuing)" >&2

# Put setup.sh on Path. The target must be ABSOLUTE: a relative one resolves against the
# link's own directory (~/.local/bin), not the workspace, so it dangles.
mkdir -p "$HOME/.local/bin"
ln -sfn "$SCRIPT_DIR/setup.sh" "$HOME/.local/bin/setup-devcontainer"
