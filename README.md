# CMU SEI Dev Container Features

Dev Container Features for CMU SEI development environments. Each feature packages
tool installation, lifecycle hooks, and configuration defaults independently.
Consumers reference packages in `devcontainer.json` using
`ghcr.io/cmu-sei/devcontainer-features/<feature>:1`.

The deployment supplies the base image, CA certificates, provider profiles,
credentials, and persistent volume. Publish the initial release to GitHub Container
Registry (GHCR) before using the registry references in the examples.

## Available features

| Feature | Purpose |
| --- | --- |
| [bedrock](src/bedrock/README.md) | Read-only checks of Bedrock account retention and GovCloud model availability. |
| [chat](src/chat/README.md) | LiteLLM, Open WebUI, Open Terminal, SearXNG, and supervisord as one bundle. |
| [claude](src/claude/README.md) | Claude Code with organizational defaults and persistent user state. |
| [codex](src/codex/README.md) | Codex CLI with profile-based configuration and persistent user state. |
| [grok](src/grok/README.md) | Grok CLI and its Bedrock token helper. |
| [herdr](src/herdr/README.md) | Herdr workspace manager, agent integrations, and a bundled skill. |
| [oh-my-logo](src/oh-my-logo/README.md) | The Oh My Logo CLI. |
| [opencode](src/opencode/README.md) | OpenCode with profile-based configuration and persistent user state. |
| [pi](src/pi/README.md) | Pi Coding Agent with profile-based configuration and persistent user state. |
| [pure-prompt](src/pure-prompt/README.md) | Pure Zsh prompt and workspace Git dirty indicator. |
| [tmux](src/tmux/README.md) | tmux with the organization's terminal defaults. |

## Repository layout

| Directory | Role |
| --- | --- |
| `src/` | Feature packages. Only their contents are published and downloaded by consumers. |
| `test/` | Dev Container CLI installation tests, one directory per feature. |
| `tools/` | Maintainer tooling: shared helper source (`lib/`), sync/validation scripts, and offline lifecycle regression tests (`runtime-tests/`). |
| `examples/` | Example consumer configuration. |
| `.github/workflows/` | Validation and publishing automation. |

## Requirements

The integration reference is `mcr.microsoft.com/devcontainers/python:3.14-trixie`,
with the `vscode` remote user, passwordless sudo, a workspace mounted before lifecycle
hooks run, and a named volume mounted at `/home/vscode/.data`. Debian/Ubuntu are the
supported OS families. Chat and Grok require system Python; Chat also requires the
C/C++ build tools and libxml2/libxslt development libraries supplied by the Python base.
Other bases need equivalent prerequisites and are not covered by the integration tests.

Install organizational CA certificates in the base Dockerfile before feature
installation, using `COPY` and `update-ca-certificates`. Feature declaration order
does not control installation order: Node and uv dependencies can download software
before a local certificate feature runs.

## Usage

Add the required features to `.devcontainer/devcontainer.json`. This example uses
an existing Dockerfile and `.devcontainer/devcontainer.env` file.

```jsonc
{
  "build": { "dockerfile": "Dockerfile" },
  "remoteUser": "vscode",
  "mounts": [
    {
      "type": "volume",
      "source": "${localWorkspaceFolderBasename}-data",
      "target": "/home/vscode/.data"
    }
  ],
  "features": {
    "ghcr.io/devcontainers/features/common-utils:2": {
      "configureZshAsDefaultShell": true,
      "upgradePackages": false
    },
    "ghcr.io/cmu-sei/devcontainer-features/claude:1": {},
    "ghcr.io/cmu-sei/devcontainer-features/codex:1": {},
    "ghcr.io/cmu-sei/devcontainer-features/pi:1": {},
    "ghcr.io/cmu-sei/devcontainer-features/tmux:1": {}
  },
  "runArgs": ["--env-file", ".devcontainer/devcontainer.env"]
}
```

Node-dependent features require `ghcr.io/devcontainers/features/node:2`. Use the
same dependency version and options across the deployment to avoid duplicate
installations.

Feature lifecycle hooks run automatically. Remove project hooks that duplicate tool
setup or automatically update installed tools; retain unrelated project hooks.

[examples/base/devcontainer.json](examples/base/devcontainer.json) selects all 11
features and uses the public Python base without profiles or an environment file.
Adapt its image or build configuration if the deployment requires CA certificates.

### Migrate an existing base devcontainer

1. Publish the initial feature release and configure package read access.
2. Replace each `"./features/<id>"` entry with
   `"ghcr.io/cmu-sei/devcontainer-features/<id>:1"`.
3. Preserve your base Dockerfile, CA certificates, profiles, runtime environment file,
   initializer, and `~/.data` volume mount.
4. Remove copied feature implementations and duplicate tool setup/update calls. Keep
   unrelated project hooks, such as shell-history initialization.
5. Rebuild the devcontainer and verify the selected tools and provider configuration.

## Runtime configuration

| Input | Default / behavior |
| --- | --- |
| `ORG_DEVCONTAINER_DIR` | `$PWD/.devcontainer` at lifecycle time; set an absolute container path for nested/custom configurations. |
| `ORG_PROFILES_DIR` | `$ORG_DEVCONTAINER_DIR/profiles`; accepts an absolute override. |
| `CONFIGURED_PROFILES` | Comma-separated profile names, in merge order. Runtime environment wins, including an explicitly empty value. For older deployments, falls back to the selector in `devcontainer.env`. CRLF is supported. |
| `CHAT_AUTOSTART` | `0`/unset: start manually with `start_chat_stack`; `1`: start on container startup. |
| AWS/provider credentials | Supplied by the deployment at runtime, never feature options or build arguments. |

### Profiles

Profiles are deployment-owned directories under `ORG_PROFILES_DIR`, one per provider,
and are not bundled in this collection. `CONFIGURED_PROFILES` selects which apply.
Each profile contributes optional per-tool fragments; a missing fragment is skipped.

| File | Consumed by | Multiple profiles |
| --- | --- | --- |
| `claude.json` | claude: `.env` merged into `~/.claude/settings.json` `env` | Merged, last wins per key. |
| `config.toml` | codex: written to `/etc/codex/config.toml` | First profile with a file wins; no merge. |
| `grok.toml` | grok: `[auth_provider.*]`/`[model.*]` tables into `/etc/grok/managed_config.toml` | Concatenated; first model is the default. |
| `opencode.json` | opencode: `~/.config/opencode/opencode.json` | `provider` and `disabled_providers` merged. |
| `models.json` | pi: `~/.pi/agent/models.json` | `providers` merged. |
| `litellm.json` | chat: `model_list` into `~/.config/litellm/config.yaml` | Concatenated. |

The `bedrock` feature runs checks only for profiles named `aws` or `awsgov`.
Its GovCloud model check reads `ANTHROPIC_DEFAULT_*_MODEL` entries from
`awsgov/claude.json`. Chat requires a profile with a nonempty LiteLLM configuration
before it can start.

### Configuration defaults

- `claude` seeds `permissions.defaultMode: "auto"` and empty commit/PR attribution
  into the user's settings (once; later user edits win), disables Claude Code's
  auto-updater, and sets VS Code's `chat.disableAIFeatures` in workspaces that use it.
- `chat` binds its services to container loopback and disables Open WebUI login.
  Keep forwarded ports private; the configuration assumes a single-user container.
- Every feature ensures `curl`, `jq`, `git`, `sudo`, and `zsh` are installed.

### Persistent state and lifecycle

Runtime assets are installed under `/usr/local/share/org-features/<id>`. State is persisted under
`~/.data`; without a mounted volume, the hooks warn and use an ordinary directory.
Reusing a volume preserves credentials and sessions. Grok and Codex executable payloads
are kept outside that persisted state so image upgrades are not hidden by old binaries.
Herdr integrations run at post-start, after every feature finishes initializing state.
The Herdr skill is bundled from release 0.9.1 with its upstream license and installed
for detected agents at post-start.

Bedrock performs read-only checks. Account administrators must configure retention
settings and model entitlements before use.

## Versions and updates

Feature package versions start at `1.0.0`. Claude, Codex, Grok, OpenCode, Pi, and
Oh My Logo expose a tool `version` option with a pinned default. Herdr uses a
checked-in release manifest and checksums, Pure is pinned to a commit, and Chat
pins its bundle dependencies. Installers run during image builds. Claude's automatic
updater is disabled; users can still update tools manually.

To release an update:

1. Change the tool pin, packaged script, or defaults and bump that feature's metadata
   `version`. Published exact feature versions are never rebuilt; the test workflow
   fails a pull request that changes a package without bumping it. A change to `tools/lib/`
   is copied into every package and requires a version bump for each.
2. Run validation and feature tests, then merge to `main`.
3. Run **Publish features**. It runs the test workflow before publishing to GHCR.
4. Rebuild consumers to resolve the new `:1` artifact. If consumers use exact versions or
   a feature lockfile, update those first. Existing containers do not hot-update.

The registry tag (`:1`, `:1.0.0`) selects the feature package. The `version` option
inside a feature entry selects the installed tool. Leave options empty to use the
release's default tool version.

Pinning top-level tool releases does not lock every transitive npm/Python dependency or
remote installer script. For byte-for-byte reproduction, also pin the base image digest,
feature artifact digests, and dependency lockfiles or use a centrally built image.

### Registry access

GHCR package visibility is configured separately from repository visibility. Grant
developers and CI read access to private packages before building. Registry
authentication runs on the host, before container runtime credentials are available.
A public index listing is optional.

The documented namespace requires this repository to be hosted at
`cmu-sei/devcontainer-features` with GitHub Actions enabled. The
[Publish features workflow](.github/workflows/release.yml) grants its publishing job
`packages: write` and runs manually from `main`, after its tests pass. It uses the
repository's `GITHUB_TOKEN`.

## Development and verification

Run these commands from the repository root. Local installation tests require Docker
and the Dev Container CLI; CI uses `@devcontainers/cli@0.87.0`.

```sh
python3 tools/sync-library.py
python3 tools/validate.py
# Offline lifecycle regression tests, with no workspace feature sources:
docker run --rm --network none -v "$PWD:/repo:ro" \
  mcr.microsoft.com/devcontainers/python:3.14-trixie bash /repo/tools/runtime-tests/runtime.sh
# Full installation smoke tests (downloads upstream tools):
devcontainer features test --skip-scenarios --remote-user vscode \
  --base-image mcr.microsoft.com/devcontainers/python:3.14-trixie --project-folder .
# Behind the corporate proxy, use your already certificate-enabled base instead:
bash tools/test-base.sh YOUR-CERTIFICATE-ENABLED-BASE
```

Edit shared helpers in `tools/lib/`, then regenerate the copies packaged in `src/*/`.
Validation rejects stale copies. Each feature archive must be self-contained: do not
source files outside its directory. CI tests each feature and gates releases on success.

The installation tests do not exercise live provider authentication, Bedrock inference,
or browser-chat conversations.

Reference: [Dev Container Feature starter](https://github.com/devcontainers/feature-starter)
and [Feature specification](https://github.com/devcontainers/spec/blob/main/docs/specs/devcontainer-features.md).
