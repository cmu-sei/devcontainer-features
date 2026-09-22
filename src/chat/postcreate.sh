#!/bin/bash
# Configure chat using deployment profiles and persistent user state.
set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/org-runtime.sh"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Persistent data volume ---
# The stack's runtime state (proxy logs, Open WebUI's DB + HF cache, the generated
# secrets, supervisord's pidfile/log) lives on the ~/.data volume so it survives
# rebuilds. The volume mounts root-owned on first create; the chown is idempotent
# and every feature that touches ~/.data does it, since any of them may run first.
org_prepare_data
mkdir -p "$DATA/litellm" "$DATA/open-webui" "$DATA/open-terminal" \
         "$DATA/searxng" "$DATA/supervisor"

# --- LiteLLM proxy config ---
# Aggregate every configured profile's model_list into a single OpenAI-compatible
# proxy config. LiteLLM's model_list is an array, so this is a concatenation — the
# jq -s form handles one or many profiles alike. Regenerated on every create rather
# than persisted, so a model added to a profile in git reaches an existing container
# on its next rebuild. Written as JSON, which is valid YAML and is what LiteLLM
# parses the file with (yaml.safe_load).
#
# This file is the gate for the whole stack: supervisord/start.sh refuses to bring
# the services up without it (no profile models => no proxy => nothing for the chat
# UI to talk to).

if [ -n "$CONFIGURED_PROFILES" ]; then
    PROFILES_LINE="CONFIGURED_PROFILES=$CONFIGURED_PROFILES"
    if [ -n "$PROFILES_LINE" ]; then
        CSV="${PROFILES_LINE#CONFIGURED_PROFILES=}"
        CSV="${CSV//$'\r'/}"
        IFS=',' read -ra CONFIGURED <<< "$CSV"

        LITELLM_FILES=()
        for profile in "${CONFIGURED[@]}"; do
            if [ -f "$PROFILES_DIR/$profile/litellm.json" ]; then
                LITELLM_FILES+=("$profile")
            fi
        done

        if [ ${#LITELLM_FILES[@]} -ge 1 ]; then
            mkdir -p "$HOME/.config/litellm"
            LITELLM_PATHS=()
            for p in "${LITELLM_FILES[@]}"; do LITELLM_PATHS+=("$PROFILES_DIR/$p/litellm.json"); done
            jq -s '{ model_list: [.[].model_list // [] | .[]] }' \
                "${LITELLM_PATHS[@]}" > "$HOME/.config/litellm/config.yaml"
        fi
    fi
fi

# --- `start_chat_stack` command ---
# Now that autostart is opt-in (CHAT_AUTOSTART=1 — see this feature's poststart.sh), this
# is the normal way to bring the stack up, so it gets a name on PATH instead of a path to
# remember. ~/.local/bin is the remote user's bin dir, already on PATH and where the uv
# tool entry points and the agent CLIs land.
#
# The wrapper invokes an installed absolute path so sibling assets resolve correctly.
mkdir -p "$HOME/.local/bin"
# Replace old symlinks without writing through them into the feature package.
rm -f "$HOME/.local/bin/start_chat_stack"
printf '#!/bin/bash\nexec bash %q "$@"\n' "$SCRIPT_DIR/supervisord/start.sh" > "$HOME/.local/bin/start_chat_stack"
chmod 755 "$HOME/.local/bin/start_chat_stack"

# --- supervisorctl alias ---
# supervisorctl defaults to 127.0.0.1:9001, but this stack binds the control endpoint
# to :6090 via supervisord.conf — point the alias at the config that ships with this
# feature so plain `supervisorctl` connects.
#
# Deleting any existing alias line first keeps this idempotent across creates.
SUPERVISORD_CONF="$SCRIPT_DIR/supervisord/supervisord.conf"
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$rc" ] || continue
    sed -i '/^alias supervisorctl=/d' "$rc"
    echo "alias supervisorctl='supervisorctl -c $SUPERVISORD_CONF'" >> "$rc"
done
