#!/bin/bash
set -euo pipefail

FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$FEATURE_DIR/org-build.sh"
org_feature_init "$FEATURE_DIR" "tmux"

# Install this feature's tmux.conf as the remote user's ~/.tmux.conf.
#
# Done at feature BUILD time rather than on every create: the config is static, so
# baking it into a cached image layer keeps it off the create path and does not clobber
# hand edits made in a running container. A dotfiles repo still wins, since the CLI
# applies dotfiles after features.
#
# The file is written whole (not appended to), so this feature is its single owner —
# see the header comment in tmux.conf about why the settings are not split across the
# features that motivate them.
USER_HOME="$(getent passwd "$_REMOTE_USER" | cut -d: -f6)"
install -m 644 -o "$_REMOTE_USER" -g "$(id -gn "$_REMOTE_USER")" \
    "$FEATURE_DIR/tmux.conf" "$USER_HOME/.tmux.conf"
