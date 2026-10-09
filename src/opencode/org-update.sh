#!/bin/bash
# Background tool updates for the agent features. Packaged by tools/sync-library.py.

# Runs a tool's own updater detached from the lifecycle hook, so container start does not
# wait on downloads and each feature's tool updates in parallel with the others. Skipped
# when the feature pinned a version at build time or ORG_FEATURES_AUTO_UPDATE=false.
org_update_in_background() {
    local feature="$1"
    shift
    [ "${ORG_FEATURES_AUTO_UPDATE:-true}" != false ] || return 0
    [ ! -e "/usr/local/share/org-features/$feature/version-pinned" ] || return 0
    local log="${XDG_CACHE_HOME:-$HOME/.cache}/org-features/$feature-update.log"
    mkdir -p "${log%/*}"
    echo "Updating $feature in the background; see $log."
    setsid -f "$@" > "$log" 2>&1 < /dev/null
}
