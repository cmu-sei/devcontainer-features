#!/bin/bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
test -f /usr/local/share/org-features/shell-completions/options.env
command -v install-completions

# A stub cobra-style CLI exercises the generator end to end.
bin="$(mktemp -d)"
cat > "$bin/democli" <<'SH'
#!/bin/bash
[ "$1" = completion ] || exit 2
case "$2" in
    zsh)  echo '#compdef democli' ;;
    bash) echo 'complete -W "run" democli' ;;
esac
SH
chmod +x "$bin/democli"
PATH="$bin:$PATH" install-completions democli
test -s /usr/local/share/zsh/site-functions/_democli
test -s /usr/local/share/bash-completion/completions/democli
zsh -fc 'print -l $fpath' | grep -qx /usr/local/share/zsh/site-functions
echo "Feature smoke test passed."
