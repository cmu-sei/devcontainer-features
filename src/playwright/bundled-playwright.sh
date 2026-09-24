#!/bin/bash
# Run the Playwright CLI bundled with @playwright/cli, whose browser builds are the ones
# playwright-cli launches. Usable as root at build time and as the user afterwards.
set -euo pipefail
if ! command -v node >/dev/null && [ -s "${NVM_DIR:-/usr/local/share/nvm}/nvm.sh" ]; then
    . "${NVM_DIR:-/usr/local/share/nvm}/nvm.sh"
fi
cli=$(node -p 'require("path").join(require("path").dirname(require.resolve("playwright-core/package.json", { paths: [process.argv[1]] })), "cli.js")' \
    "$(npm root -g)/@playwright/cli")
exec node "$cli" "$@"
