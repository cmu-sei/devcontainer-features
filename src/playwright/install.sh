#!/bin/bash
set -euo pipefail
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$FEATURE_DIR/org-build.sh"
org_feature_init "$FEATURE_DIR" playwright

VERSION="${VERSION:-0.1.21}"
SYSTEMDEPS="${SYSTEMDEPS:-chromium}"
BROWSERS="${BROWSERS:-chromium}"
TRUSTLOCALCAS="${TRUSTLOCALCAS:-true}"
DESKTOP="${DESKTOP:-false}"
DESKTOPPASSWORD="${DESKTOPPASSWORD:-vscode}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][a-zA-Z0-9.-]+)?$ ]] || { echo "Use an exact tool version." >&2; exit 1; }
for list in "$SYSTEMDEPS" "$BROWSERS"; do
    [[ "$list" =~ ^(none|((chromium|firefox|webkit),?)+)$ ]] \
        || { echo "playwright: browser lists take chromium, firefox, webkit, or none; got '$list'." >&2; exit 1; }
done
[[ "$DESKTOPPASSWORD" =~ ^[A-Za-z0-9._@%+-]+$ ]] \
    || { echo "playwright: desktopPassword may only contain letters, digits and ._@%+-" >&2; exit 1; }

DEST=/usr/local/share/org-features/playwright
printf 'BROWSERS=%s\nTRUSTLOCALCAS=%s\nDESKTOP=%s\nDESKTOPPASSWORD=%s\n' \
    "$BROWSERS" "$TRUSTLOCALCAS" "$DESKTOP" "$DESKTOPPASSWORD" > "$DEST/options.env"

# --- Playwright CLI ---
# Node is an installsAfter, not a dependsOn: a dependsOn entry whose options differ from the
# deployment's own node feature entry installs Node a second time.
su - "$_REMOTE_USER" -s /bin/bash -c "
    set -euo pipefail
    if [ -s '${NVM_DIR:-/usr/local/share/nvm}/nvm.sh' ]; then . '${NVM_DIR:-/usr/local/share/nvm}/nvm.sh'; fi
    command -v npm >/dev/null || { echo 'playwright: npm not found; add ghcr.io/devcontainers/features/node:2 to features.' >&2; exit 1; }
    export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
    npm install -g --ignore-scripts @playwright/cli@$VERSION
"

# --- Browser OS packages ---
# Use the Playwright bundled with the CLI, so the package list matches the browser builds it
# downloads. install-deps runs apt itself and needs root, which the build has.
if [ "$SYSTEMDEPS" != none ]; then
    IFS=',' read -ra DEPS <<< "$SYSTEMDEPS"
    bash "$DEST/bundled-playwright.sh" install-deps "${DEPS[@]}"
    rm -rf /var/lib/apt/lists/*
fi

# --- Chromium CA trust ---
if [ "$TRUSTLOCALCAS" = true ] && ! command -v certutil >/dev/null; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends libnss3-tools
    rm -rf /var/lib/apt/lists/*
fi

# --- Headed-browser desktop ---
# WSL renders headed browsers natively through WSLg, so the desktop is only built elsewhere.
# The upstream desktop-lite installer is pinned by commit and checksum. Its entrypoint is
# deliberately not registered: the services start on demand with playwright-desktop.
DESKTOP_LITE_COMMIT=f15b529848d77c462d1bf8004c0ff465e124fdd3  # feature_desktop-lite_1.2.10
DESKTOP_LITE_SHA256=7b4739fb821eb3f24f00a33c80226b49c50db7814c01a2df365bd1afe0077bbb
if [ "$DESKTOP" = true ]; then
    if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "playwright: WSL detected; skipping the desktop, WSLg displays headed browsers."
    else
        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT
        curl -fsSL --retry 3 -o "$tmp/desktop-lite.sh" \
            "https://raw.githubusercontent.com/devcontainers/features/$DESKTOP_LITE_COMMIT/src/desktop-lite/install.sh"
        printf '%s  %s\n' "$DESKTOP_LITE_SHA256" "$tmp/desktop-lite.sh" | sha256sum -c -
        PASSWORD="$DESKTOPPASSWORD" USERNAME="$_REMOTE_USER" WEBPORT=6080 VNCPORT=5901 bash "$tmp/desktop-lite.sh"
        install -m 755 "$DEST/desktop.sh" /usr/local/bin/playwright-desktop
        # desktop-lite's init script defaults to display :1; point shells there unless the
        # host already supplies a display.
        echo '[ -n "${DISPLAY:-}" ] || export DISPLAY=:1' > /etc/profile.d/playwright-display.sh
        grep -qF '# playwright feature' /etc/zsh/zshenv 2>/dev/null \
            || printf '\n%s\n' '[ -r /etc/profile.d/playwright-display.sh ] && . /etc/profile.d/playwright-display.sh  # playwright feature' >> /etc/zsh/zshenv
    fi
fi
