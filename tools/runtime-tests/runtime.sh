#!/bin/bash
# Runs inside a disposable Python devcontainer image; never run directly on a host.
set -euo pipefail
[ -f /.dockerenv ] || { echo 'Run this test inside Docker.' >&2; exit 1; }
export _REMOTE_USER=vscode
mkdir -p /home/vscode/.local
chown root:root /home/vscode/.local
for feature in /repo/src/*; do
    . "$feature/org-build.sh"
    org_feature_init "$feature" "$(basename "$feature")"
    # The first feature to run must hand ~/.local back to the remote user.
    [ "$(stat -c %U /home/vscode/.local)" = vscode ]
done
# Test the actual installed layout, with no feature implementation in the workspace.
su - vscode -s /bin/bash -c 'python3 /repo/tools/runtime-tests/runtime_test.py'
