#!/bin/bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/org-runtime.sh"
. "$(dirname "${BASH_SOURCE[0]}")/org-update.sh"

# All features have finished migrating persistent state before this phase.
for agent in claude codex opencode pi grok; do
    command -v "$agent" &>/dev/null || continue
    case "$agent" in
        claude)   AGENT_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}" ;;
        codex)    AGENT_DIR="${CODEX_HOME:-$HOME/.codex}" ;;
        opencode) AGENT_DIR="$HOME/.config/opencode" ;;
        pi)       AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}" ;;
        grok)     AGENT_DIR="${GROK_HOME:-$HOME/.grok}" ;;
    esac
    mkdir -p "$AGENT_DIR"
    echo "Installing Herdr integration for $agent..."
    herdr integration install "$agent" || true
    case "$agent" in
        claude|pi|opencode) SKILL_DIR="$AGENT_DIR/skills/herdr" ;;
        *) SKILL_DIR="$HOME/.agents/skills/herdr" ;;
    esac
    mkdir -p "$SKILL_DIR"
    # The binary prints the skill matching its own release, so this follows `herdr update`.
    herdr --skill > "$SKILL_DIR/SKILL.md.tmp" && mv "$SKILL_DIR/SKILL.md.tmp" "$SKILL_DIR/SKILL.md" || rm -f "$SKILL_DIR/SKILL.md.tmp"
done

# Skills above come from the running binary; an update reaches them on the next start.
org_update_in_background herdr herdr update
