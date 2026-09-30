#!/bin/bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
expected=$(jq -r '.options.version.default' /usr/local/share/org-features/codex/devcontainer-feature.json)
codex --version | grep -F "$expected"
bash /usr/local/share/org-features/codex/postcreate.sh
codex --version | grep -F "$expected"
resolved="$(readlink -f "$(command -v codex)")"
[[ "$resolved" == "$(readlink -f "$HOME/.codex")/packages/standalone/releases/"* ]]

# Exercise the real updater's installation detection without downloading or
# running an upstream installer. An unknown installation fails before curl.
stub_dir="$(mktemp -d)"
trap 'rm -rf "$stub_dir"' EXIT
cat > "$stub_dir/curl" <<'STUB'
#!/bin/bash
set -euo pipefail
[ "$*" = "-fsSL https://chatgpt.com/codex/install.sh" ]
cat <<'INSTALLER'
[ "$CODEX_NON_INTERACTIVE" = 1 ]
printf 'standalone updater reached\n' > "$CODEX_UPDATE_TEST_MARKER"
INSTALLER
STUB
chmod +x "$stub_dir/curl"
export CODEX_UPDATE_TEST_MARKER="$stub_dir/update-marker"
PATH="$stub_dir:$PATH" codex update
grep -qx 'standalone updater reached' "$CODEX_UPDATE_TEST_MARKER"
echo "Feature smoke test passed."
