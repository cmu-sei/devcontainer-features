# Persistent Shell History

Keeps bash, zsh, and REPL history on the persistent volume, so it survives a rebuild.

```json
{
  "features": {
    "ghcr.io/cmu-sei/devcontainer-features/shell-history:1": {
      "include": "bash,zsh,python,node"
    }
  }
}
```

| Option | Default | Meaning |
| --- | --- | --- |
| `include` | `bash,zsh,python,node` | Any of `bash`, `zsh`, `python` (3.13+ `PYTHON_HISTORY`), `node`, `psql`, `sqlite3`, `less`. |
| `directory` | `.data/shell-history` | Relative to the user's home unless absolute. Must be on a persistent volume. |

The settings live in `/usr/local/share/org-features/shell-history/history.sh`,
sourced from `/etc/bash.bashrc`, `/etc/zsh/zshrc`, and the user's `~/.zshrc`. The
`~/.zshrc` line is needed because VS Code's zsh integration resets `HISTFILE` between
the two zsh files; the system files still apply if a dotfiles repo replaces
`~/.zshrc`. oh-my-zsh keeps a `HISTFILE` that is already set.

- **Written per command** (zsh `INC_APPEND_HISTORY`, bash `history -a` in
  `PROMPT_COMMAND`): a rebuild SIGKILLs open terminals, which would otherwise lose
  everything since they started.
- **Applies once the directory exists.** The create step makes it; a terminal opened
  before that, or a shell whose home has no volume (`sudo -i`), keeps its default.
- On first create, an existing `~/.bash_history` or `~/.zsh_history` seeds the volume.
  An existing empty history file is preserved, so clearing history is permanent
  across later creates.
- Custom history destinations are prepared for the remote user, including fresh
  root-owned volumes. Only the destination directory's ownership is adjusted.
- Plain zsh gets a 10,000-entry history limit. Existing non-default limits are
  retained, and settings made later in `~/.zshrc` (including `SAVEHIST=0`) take
  precedence when the feature is sourced again.
- Bash history flushing preserves the previous exit status for existing prompt
  hooks and supports both string and array `PROMPT_COMMAND` values.

History files are keyed by the volume, so each project's container keeps its own.

See the [collection README](../../README.md) for the supported base, profiles, persistence, and release process.
