#!/bin/bash
set -euo pipefail
command -v playwright-desktop
playwright-desktop status | grep -F stopped
playwright-desktop start
playwright-desktop status | grep -F 'Password: scenario'
playwright-desktop stop
# Every browser option was off.
[ ! -e "$HOME/.data/playwright" ] || [ -z "$(ls -A "$HOME/.data/playwright")" ]
echo "Feature smoke test passed."
