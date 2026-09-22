#!/bin/bash
# Configure opencode using deployment profiles and persistent user state.
set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/org-runtime.sh"


# --- Persistent data volume ---
# OpenCode keeps its data in two XDG directories rather than one ~/.opencode, so both
# are redirected onto the ~/.data volume: sessions and data (share), plus model
# selection and prompt history (state). Config (~/.config/opencode) is deliberately
# NOT persisted — it is regenerated from the profiles below on every create.
#
# The volume mounts root-owned on first create; the chown is idempotent and every
# feature that touches ~/.data does it, since any of them may run first.
org_prepare_data
mkdir -p "$DATA/opencode" "$DATA/opencode-state"

# --- Symlink the data directories into the persistent volume ---
# If the volume directory is empty and the home directory has content from the feature
# installer, seed the volume with those files before symlinking.
link_to_volume() {
    local home_dir="$1"
    local vol_dir="$2"
    if [ -d "$home_dir" ] && [ ! -L "$home_dir" ]; then
        if [ -z "$(ls -A "$vol_dir" 2>/dev/null)" ]; then
            cp -a "$home_dir/." "$vol_dir/"
        fi
        rm -rf "$home_dir"
    fi
    mkdir -p "$(dirname "$home_dir")"
    ln -sfn "$vol_dir" "$home_dir"
}

link_to_volume "$HOME/.local/share/opencode" "$DATA/opencode"
link_to_volume "$HOME/.local/state/opencode" "$DATA/opencode-state"

# --- OpenCode config from the configured profiles ---
# Regenerated on every create rather than persisted, so a provider or model added to a
# profile in git reaches an existing container on its next rebuild.

if [ -n "$CONFIGURED_PROFILES" ]; then
    PROFILES_LINE="CONFIGURED_PROFILES=$CONFIGURED_PROFILES"
    if [ -n "$PROFILES_LINE" ]; then
        CSV="${PROFILES_LINE#CONFIGURED_PROFILES=}"
        CSV="${CSV//$'\r'/}"
        IFS=',' read -ra CONFIGURED <<< "$CSV"

        OC_FILES=()
        for profile in "${CONFIGURED[@]}"; do
            if [ -f "$PROFILES_DIR/$profile/opencode.json" ]; then
                OC_FILES+=("$profile")
            fi
        done

        if [ ${#OC_FILES[@]} -eq 1 ]; then
            mkdir -p "$HOME/.config/opencode"
            cp "$PROFILES_DIR/${OC_FILES[0]}/opencode.json" "$HOME/.config/opencode/opencode.json"
        elif [ ${#OC_FILES[@]} -ge 2 ]; then
            mkdir -p "$HOME/.config/opencode"
            OC_PATHS=()
            for p in "${OC_FILES[@]}"; do OC_PATHS+=("$PROFILES_DIR/$p/opencode.json"); done
            # Merge providers and disabled_providers; model is omitted so
            # OpenCode uses whatever the user last selected.
            jq -s '{
                "$schema": "https://opencode.ai/config.json",
                disabled_providers: ([.[].disabled_providers // [] | .[]] | unique | if length > 0 then . else null end),
                provider: (reduce (.[].provider // {}) as $p ({}; . * $p))
            } | with_entries(select(.value != null))' "${OC_PATHS[@]}" > "$HOME/.config/opencode/opencode.json"
        fi
    fi
fi

