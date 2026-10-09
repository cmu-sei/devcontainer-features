# OpenCode

Installs the OpenCode CLI via the official installer script.

```json
{
  "features": {
    "ghcr.io/cmu-sei/devcontainer-features/opencode:1": {}
  }
}
```

| Option | Default | Meaning |
| --- | --- | --- |
| `version` | empty | Exact upstream tool version to pin at image build time. Leave empty to install the latest release. |

Each container start runs `opencode upgrade` in the background unless `version` pins a release;
see [Versions and updates](../../README.md#versions-and-updates).

See the [collection README](../../README.md) for the supported base, profiles, persistence, and release process.
