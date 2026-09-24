#!/bin/bash
# Keep Playwright's browser cache on the persistent volume and download the configured browsers.
set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/org-runtime.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPTIONS="$SCRIPT_DIR/options.env"
option() { [ -f "$OPTIONS" ] || return 0; sed -n "s/^$1=//p" "$OPTIONS" | tail -n 1; }
BROWSERS="$(option BROWSERS)"
BROWSERS="${BROWSERS:-chromium}"

# --- Persistent browser cache ---
# Browsers are hundreds of megabytes each, so they live on the ~/.data volume. Every Playwright
# version on the machine (the CLI's and each project's) shares this one cache. Leave it alone
# when the deployment already relocated it: PLAYWRIGHT_BROWSERS_PATH is set, or the default path
# is a mount point, which rm -rf below would empty rather than remove.
CACHE="$HOME/.cache/ms-playwright"
if [ -z "${PLAYWRIGHT_BROWSERS_PATH:-}" ] && ! mountpoint -q "$CACHE" 2>/dev/null; then
    org_prepare_data
    vol_dir="$DATA/playwright"
    mkdir -p "$vol_dir" "$HOME/.cache"
    if [ -d "$CACHE" ] && [ ! -L "$CACHE" ]; then
        if [ -z "$(ls -A "$vol_dir" 2>/dev/null)" ]; then
            cp -a "$CACHE/." "$vol_dir/"
        fi
        rm -rf "$CACHE"
    fi
    ln -sfn "$vol_dir" "$CACHE"
fi

# --- Default browser for playwright-cli ---
# The CLI otherwise defaults to Google Chrome, which is not installed here and does not exist for
# Linux arm64. Make the first downloaded browser the default in the user-level config, the lowest
# layer: a project's .playwright/cli.config.json, PLAYWRIGHT_MCP_BROWSER and --browser all
# override it. Seeded only when unset, so a developer's own choice survives later creates.
if [ "$BROWSERS" != none ]; then
    CLI_CONFIG="$HOME/.playwright/cli.config.json"
    mkdir -p "$(dirname "$CLI_CONFIG")"
    [ -s "$CLI_CONFIG" ] || echo '{}' > "$CLI_CONFIG"
    if ! jq -e '.browser.browserName' "$CLI_CONFIG" &>/dev/null; then
        jq --arg name "${BROWSERS%%,*}" '.browser = ((.browser // {}) + { browserName: $name })' \
            "$CLI_CONFIG" > "$CLI_CONFIG.tmp" && mv "$CLI_CONFIG.tmp" "$CLI_CONFIG"
    fi
fi

# --- Browsers for playwright-cli ---
# Already-present builds are skipped, so this is quick on a reused volume. Warn-only: a create
# must not fail on a download, and the fix is one command away.
if [ "$BROWSERS" != none ]; then
    export NODE_EXTRA_CA_CERTS="${NODE_EXTRA_CA_CERTS:-/etc/ssl/certs/ca-certificates.crt}"
    IFS=',' read -ra LIST <<< "$BROWSERS"
    if ! bash "$SCRIPT_DIR/bundled-playwright.sh" install "${LIST[@]}"; then
        echo -e "\e[33m⚠️  Playwright browser download failed; retry with: playwright-cli install-browser <browser>\e[0m"
    fi
fi
