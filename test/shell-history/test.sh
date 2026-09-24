#!/bin/bash
set -euo pipefail
assets=/usr/local/share/org-features/shell-history
test -f "$assets/history.sh"
for rc in /etc/bash.bashrc /etc/zsh/zshrc "$HOME/.zshrc"; do
    grep -qF '# shell-history feature' "$rc"
done
bash "$assets/postcreate.sh"
dir="$HOME/.data/shell-history"
test -f "$dir/.zsh_history" && test -f "$dir/.bash_history"
[ "$(bash -ic 'echo "$HISTFILE"' 2>/dev/null | tail -n 1)" = "$dir/.bash_history" ]
[ "$(zsh -ic 'echo "$HISTFILE"' 2>/dev/null | tail -n 1)" = "$dir/.zsh_history" ]
[ "$(zsh -ic 'echo "$PYTHON_HISTORY"' 2>/dev/null | tail -n 1)" = "$dir/python_history" ]
echo "Feature smoke test passed."
