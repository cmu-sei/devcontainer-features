# Herdr

Installs the latest Herdr terminal workspace manager via the official installer script,
which verifies the release checksum. Each agent gets the Herdr skill from `herdr --skill`,
so it matches the installed release.
The agent hooks it installs run `python3`; when the image lacks a complete Python standard
library (some bases ship only `python3-minimal`), the feature installs the `python3` package.
It installs after the official Python feature, so a Python declared there is used instead.
Each container start runs `herdr update` in the background; see
[Versions and updates](../../README.md#versions-and-updates).

```json
{
  "features": {
    "ghcr.io/cmu-sei/devcontainer-features/herdr:1": {}
  }
}
```


See the [collection README](../../README.md) for the supported base, profiles, persistence, and release process.
