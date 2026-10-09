# Codex CLI

Installs the OpenAI Codex CLI via the official installer script.

```json
{
  "features": {
    "ghcr.io/cmu-sei/devcontainer-features/codex:1": {}
  }
}
```

| Option | Default | Meaning |
| --- | --- | --- |
| `version` | empty | Exact upstream tool version to pin at image build time. Leave empty to install the latest release. |

Each container start runs `codex update` in the background unless `version` pins a release;
see [Versions and updates](../../README.md#versions-and-updates).

The bundled commercial `aws` profile defaults to GPT-6.1 Sol
(`us.openai.gpt-6.1-sol`) through Bedrock Runtime in `us-east-1`. Codex 0.159.1
added native GPT-6.1 Sol entries to its Bedrock catalogs; use that version or newer
with this profile. Rebuild the container to install the updated CLI and regenerate
the model picker. Existing user model/provider settings still take precedence.
See the [Codex changelog](https://learn.chatgpt.com/docs/changelog) and
[AWS model card](https://docs.aws.amazon.com/bedrock/latest/userguide/model-card-openai-gpt-6-1-sol.html).

Codex keeps its packages in `~/.codex` (persisted at `~/.data/codex`) so `codex update`
works. Rebuilding resets Codex to the release installed in the image (the latest at build
time unless `version` pins one) and removes other saved releases.

See the [collection README](../../README.md) for the supported base, profiles, persistence, and release process.
