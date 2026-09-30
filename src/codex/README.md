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
| `version` | `0.159.2` | Exact upstream tool version installed at image build time. |

The bundled commercial `aws` profile defaults to GPT-6.1 Sol
(`us.openai.gpt-6.1-sol`) through Bedrock Runtime in `us-east-1`. Codex 0.159.1
added native GPT-6.1 Sol entries to its Bedrock catalogs; use that version or newer
with this profile. Rebuild the container to install the updated CLI and regenerate
the model picker. Existing user model/provider settings still take precedence.
See the [Codex changelog](https://learn.chatgpt.com/docs/changelog) and
[AWS model card](https://docs.aws.amazon.com/bedrock/latest/userguide/model-card-openai-gpt-6-1-sol.html).

See the [collection README](../../README.md) for the supported base, profiles, persistence, and release process.
