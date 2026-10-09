# Herdr

Installs the latest Herdr terminal workspace manager via the official installer script,
which verifies the release checksum. Each agent gets the Herdr skill from `herdr --skill`,
so it matches the installed release.
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
