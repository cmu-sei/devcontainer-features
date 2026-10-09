# Grok CLI

Installs xAI's Grok CLI (Grok Build) via the official installer script, plus the Bedrock API key helper it needs to reach Amazon Bedrock.

```json
{
  "features": {
    "ghcr.io/cmu-sei/devcontainer-features/grok:1": {}
  }
}
```

| Option | Default | Meaning |
| --- | --- | --- |
| `version` | empty | Exact upstream tool version to pin at image build time. Leave empty to install the latest release. |

Each container start runs `grok update` in the background unless `version` pins a release;
see [Versions and updates](../../README.md#versions-and-updates).
After updating, it deletes downloaded Grok releases that `~/.grok/bin` no longer uses, so
old binaries do not pile up on the persisted volume.

See the [collection README](../../README.md) for the supported base, profiles, persistence, and release process.
