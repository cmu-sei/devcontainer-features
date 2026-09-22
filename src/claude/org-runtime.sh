#!/bin/bash
# Shared runtime contract. Packaged into each feature by tools/sync-library.py.
export PATH="$HOME/.local/bin:$PATH"
DEVCONTAINER_DIR="${ORG_DEVCONTAINER_DIR:-$PWD/.devcontainer}"
PROFILES_DIR="${ORG_PROFILES_DIR:-$DEVCONTAINER_DIR/profiles}"
DEVENV="$DEVCONTAINER_DIR/devcontainer.env"

# Prefer the container environment; retain compatibility with existing deployments.
# Read only the profile selector, never execute an environment file as shell code.
if [ "${CONFIGURED_PROFILES+x}" != x ]; then
    CONFIGURED_PROFILES=""
    if [ -f "$DEVENV" ]; then
        CONFIGURED_PROFILES=$(sed -n 's/^CONFIGURED_PROFILES=//p' "$DEVENV" | tail -n 1)
    fi
fi
CONFIGURED_PROFILES="${CONFIGURED_PROFILES//$'\r'/}"
export CONFIGURED_PROFILES

org_prepare_data() {
    DATA="$HOME/.data"
    mkdir -p "$DATA"
    if [ ! -w "$DATA" ]; then
        if [ "$(id -u)" = 0 ]; then
            chown "$(id -u):$(id -g)" "$DATA"
        else
            sudo -n chown "$(id -u):$(id -g)" "$DATA"
        fi
    fi
    if command -v mountpoint >/dev/null && ! mountpoint -q "$DATA"; then
        echo "org-features: $DATA is not a volume mount; state will not survive container removal." >&2
    fi
}

org_has_profile() {
    case ",$CONFIGURED_PROFILES," in
        *",$1,"*) return 0 ;;
        *) return 1 ;;
    esac
}
