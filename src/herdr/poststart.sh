#!/bin/bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/org-runtime.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    install -m 644 "$SCRIPT_DIR/herdr-skill.md" "$SKILL_DIR/SKILL.md"
done
