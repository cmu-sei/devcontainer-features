# Shell Completions

Generates zsh, bash, and fish completions for CLIs installed by other features. Files
go to the system completion directories, so they work with or without oh-my-zsh:

| Shell | Directory |
| --- | --- |
| zsh | `/usr/local/share/zsh/site-functions/_<cli>` |
| bash | `/usr/local/share/bash-completion/completions/<cli>` |
| fish | `/usr/local/share/fish/vendor_completions.d/<cli>.fish` |

```json
{
  "features": {
    "ghcr.io/cmu-sei/devcontainer-features/shell-completions:1": {
      "commands": "just,kubectl,helm,minikube",
      "shells": "zsh,bash"
    }
  }
}
```

| Option | Default | Meaning |
| --- | --- | --- |
| `commands` | `auto` | Comma-separated CLIs. `auto` is every known CLI on PATH: `just`, `kubectl`, `helm`, `minikube`, `uv`, `docker`, `gh`, `rg`, `fd`, `codex`. Any other name uses `<cli> completion <shell>` (cobra and clap). |
| `shells` | `zsh,bash` | Any of `zsh`, `bash`, `fish`. |

Completions are generated at build time for CLIs installed before this feature (see
`installsAfter`), and again on create for CLIs installed or upgraded later. A CLI
built by a project's own lifecycle script can add its own:

```sh
install-completions example
```

A missing CLI is skipped; a failed generator warns and never fails the build. The
generated scripts are static — tools like `just` still list recipes live on Tab.

bash loads these files only when the `bash-completion` package is installed, as it is
in the Dev Containers base images. `SHELL_COMPLETIONS_PREFIX` (default
`/usr/local/share`) relocates the output, e.g. for tests.

See the [collection README](../../README.md) for the supported base, profiles, persistence, and release process.
