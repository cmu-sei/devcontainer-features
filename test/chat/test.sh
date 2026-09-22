#!/bin/bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
for tool in supervisord supervisorctl litellm open-webui open-terminal; do
    command -v "$tool"
done
test -x "$HOME/.local/searxng-venv/bin/python"
test -f "$HOME/.local/searxng-src/searx/webapp.py"
bash /usr/local/share/org-features/chat/postcreate.sh
command -v start_chat_stack
bash /usr/local/share/org-features/chat/poststart.sh
echo "Feature smoke test passed."
