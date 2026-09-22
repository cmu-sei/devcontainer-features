#!/bin/bash
# Configure herdr using deployment profiles and persistent user state.
set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/org-runtime.sh"

# --- Persistent data volume ---
# A single Docker volume at ~/.data/ stores all agent data and shell history to survive
# container rebuilds. The volume mounts root-owned on first create; the chown is
# idempotent and every feature that touches ~/.data does it, since any of them may run
# first.
org_prepare_data
mkdir -p "$DATA/herdr" "$HOME/.config"

# --- Symlink the config directory into the persistent volume ---
# Herdr keeps its state under ~/.config/herdr (an XDG dir, not a ~/.herdr), so that is
# what gets redirected onto the volume — saved layouts, conversations and worktrees all
# live there. If the volume directory is empty and the home directory has content from
# the feature installer, seed the volume with those files before symlinking.
if [ -d "$HOME/.config/herdr" ] && [ ! -L "$HOME/.config/herdr" ]; then
    if [ -z "$(ls -A "$DATA/herdr" 2>/dev/null)" ]; then
        cp -a "$HOME/.config/herdr/." "$DATA/herdr/"
    fi
    rm -rf "$HOME/.config/herdr"
fi
ln -sfn "$DATA/herdr" "$HOME/.config/herdr"

# --- Seed Herdr's config (first create only) ---
# Login shells load ~/.profile as well as interactive shell configuration, keeping
# ~/.local/bin and the container's language tools available in panes. onboarding = false
# makes the first create fully automated. Seeded only once: Herdr's own settings writes
# and any later user edits belong to the user, and this file is on the volume.
if [ ! -f "$HOME/.config/herdr/config.toml" ]; then
    cat > "$HOME/.config/herdr/config.toml" <<'EOF'
onboarding = false

[terminal]
shell_mode = "login"

[worktrees]
directory = "~/.data/herdr/worktrees"
EOF
fi

