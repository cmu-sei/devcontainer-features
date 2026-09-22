#!/bin/bash
set -euo pipefail

FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$FEATURE_DIR/org-build.sh"
org_feature_init "$FEATURE_DIR" "pure-prompt"

# Install the Pure Zsh prompt (https://github.com/sindresorhus/pure) and wire it into
# the remote user's ~/.zshrc in place of the oh-my-zsh theme that common-utils sets up.
#
# Done at feature BUILD time rather than on every create: baking it into a cached
# image layer keeps it out of the create path entirely. The feature's poststart.sh
# carries only the one piece that needs the workspace — the git dirty indicator.
#
# Ordered after common-utils via installsAfter so zsh, oh-my-zsh and ~/.zshrc exist
# by the time this runs. The body runs as the remote user so the clone and the .zshrc
# edits land in that user's home. No CA env is needed: git trusts the system bundle
# (/etc/ssl/certs/ca-certificates.crt), which already carries any custom CAs.
#
# Idempotent throughout, so re-running it by hand in a live container is safe: an
# existing clone is refreshed in place, and the .zshrc edits are skipped once
# `prompt pure` is in the file.

su - "${_REMOTE_USER}" -s /bin/bash -c '
    set -euo pipefail

    PURE_DIR="$HOME/.zsh/pure"
    ZSHRC="$HOME/.zshrc"

    if [ ! -d "$PURE_DIR/.git" ]; then
        mkdir -p "$PURE_DIR"
        git init -q "$PURE_DIR"
        git -C "$PURE_DIR" remote add origin https://github.com/sindresorhus/pure.git
    fi
    git -C "$PURE_DIR" fetch -q --depth 1 origin 90c6a129b46bde1d656244c68a3ae142b78e0cc3
    git -C "$PURE_DIR" checkout -q --detach FETCH_HEAD

    [ -f "$ZSHRC" ] || touch "$ZSHRC"

    if ! grep -q "^prompt pure$" "$ZSHRC"; then
        # Pure has to be on FPATH BEFORE oh-my-zsh is sourced (that is what runs
        # compinit), so it is spliced in at the ZSH_THEME line rather than appended.
        # Blanking ZSH_THEME hands the prompt over to Pure — otherwise the
        # devcontainers theme keeps drawing its own on top.
        sed -i "s|^ZSH_THEME=.*|ZSH_THEME=\"\"\n\nFPATH=\$HOME/.zsh/pure:\$FPATH|" "$ZSHRC"

        {
            echo ""
            echo "# Pure prompt"
            # Only reached when the sed above found no ZSH_THEME line to splice into
            # (a .zshrc without oh-my-zsh). Nothing runs compinit in that case, so
            # setting FPATH here, next to promptinit, is enough.
            if ! grep -q "^FPATH=.*\.zsh/pure" "$ZSHRC"; then
                echo "FPATH=\$HOME/.zsh/pure:\$FPATH"
            fi
            echo "autoload -U promptinit; promptinit"
            echo "prompt pure"
        } >> "$ZSHRC"
    fi
'
