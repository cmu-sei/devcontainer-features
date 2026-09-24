# Playwright

Installs the [Playwright CLI](https://github.com/microsoft/playwright-cli) (`playwright-cli`)
and everything a container needs to run its browsers: their OS packages, a browser cache on
the persistent volume, trust for local CAs in Chromium, and an optional desktop for headed
browsers.

```json
{
  "features": {
    "ghcr.io/devcontainers/features/node:2": {},
    "ghcr.io/cmu-sei/devcontainer-features/playwright:1": {
      "systemDeps": "chromium,firefox",
      "desktop": true
    }
  }
}
```

| Option | Default | Meaning |
| --- | --- | --- |
| `version` | `0.1.21` | Exact `@playwright/cli` version installed at image build time. |
| `systemDeps` | `chromium` | Browsers whose OS packages are installed at build time: `chromium`, `firefox`, `webkit`, or `none`. |
| `browsers` | `chromium` | Browsers downloaded on create for the CLI: `chromium`, `firefox`, `webkit`, or `none`. The first is the CLI's default browser. |
| `trustLocalCAs` | `true` | Import the CAs under `/usr/local/share/ca-certificates` into Chromium's trust store on each start. |
| `desktop` | `false` | Install an on-demand VNC/noVNC desktop for headed browsers. Skipped on WSL. |
| `desktopPassword` | `vscode` | VNC password for the desktop; `noPassword` disables it. |

## Node

The feature needs npm from `ghcr.io/devcontainers/features/node`, and fails the build without
it. Node is ordered before this feature but is not a `dependsOn`: a dependency whose options
differ from the deployment's own node entry installs Node a second time.

## Browsers and OS packages

Both `systemDeps` and `browsers` use the Playwright version bundled with the CLI, so the
packages and builds match what `playwright-cli` launches. A project's own `@playwright/test`
may pin a different version; install its browsers from the project, for example
`npx playwright install chromium` in a lifecycle script. `systemDeps` usually covers those too.

Upstream, the CLI defaults to Google Chrome, which this feature does not install and which
does not exist for Linux arm64. The create hook instead makes the first `browsers` entry the
default, as `browser.browserName` in the user-level `~/.playwright/cli.config.json`. That is the
lowest-precedence layer, so a project's `.playwright/cli.config.json`,
`PLAYWRIGHT_MCP_BROWSER`, and `--browser` still win. An existing `browserName` there is kept.

## Persistence

`~/.cache/ms-playwright` is symlinked to `~/.data/playwright`, so downloads survive rebuilds
and every Playwright version in the container shares one cache. The cache is left in place
when `PLAYWRIGHT_BROWSERS_PATH` is set or the path is already a mount point.

## Local CAs

On Linux, Chromium trusts the user's NSS database (`~/.pki/nssdb`), not the system store. The
start hook imports every `*.crt` under `/usr/local/share/ca-certificates`, including CAs a
project's create script adds, and removes ones it imported earlier that no longer exist.
Firefox is not covered.

## Desktop

With `desktop` enabled, the build installs the upstream
[desktop-lite](https://github.com/devcontainers/features/tree/main/src/desktop-lite) feature's
installer, pinned by commit and checksum. Nothing starts automatically:

```sh
playwright-desktop start    # Xvnc on :1, noVNC on http://localhost:6080
playwright-desktop status
playwright-desktop stop
```

Forward port 6080 in the deployment's `forwardPorts`. Shells default `DISPLAY` to `:1` when the
host provides none. On WSL the desktop is skipped, since WSLg displays headed browsers.

The feature also enables the container `init` process, which reaps the processes browsers leave
behind, and adds the Playwright VS Code extension.

See the [collection README](../../README.md) for the supported base, profiles, persistence, and release process.
