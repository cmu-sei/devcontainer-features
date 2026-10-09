# Claude Code

Installs the Claude Code CLI via the official installer script.

```json
{
  "features": {
    "ghcr.io/cmu-sei/devcontainer-features/claude:1": {}
  }
}
```

| Option | Default | Meaning |
| --- | --- | --- |
| `version` | empty | Exact upstream tool version to pin at image build time. Leave empty to install the latest release. |
| `bedrock` | `false` | Use Amazon Bedrock. Writes `CLAUDE_CODE_USE_BEDROCK=1` into `~/.claude/settings.json` `env`. Bedrock still needs `AWS_REGION` and credentials from the container. |

Each container start runs `claude update` in the background unless `version` pins a release;
see [Versions and updates](../../README.md#versions-and-updates).

## Bedrock models

The feature does not pin Bedrock models. Unpinned, Claude Code resolves each `/model` tier
to its own built-in Bedrock default, and those defaults move to newer models as Claude Code
updates. As of Claude Code 2.1.295 in `us-*` regions:

| Tier | Resolves to |
| --- | --- |
| Default model, `opus` | `us.anthropic.claude-opus-5-5` |
| `fable` | `us.anthropic.claude-fable-5-1` |
| `sonnet` | `us.anthropic.claude-sonnet-4-5-20250929-v1:0` |
| `haiku` | `us.anthropic.claude-haiku-4-5-20251001-v1:0` |

Background tasks such as session titles use the default Sonnet model unless
`ANTHROPIC_DEFAULT_HAIKU_MODEL` is set. When a default is not enabled in the account,
Claude Code falls back to an earlier model for that session. To pin a tier anyway, set
`ANTHROPIC_DEFAULT_<TIER>_MODEL` in a profile's `claude.json` or in the `env` block of
`~/.claude/settings.json`, where creates keep values you set. Pinning `sonnet` without
`opus` also makes Sonnet the default model. See [Claude Code on Amazon Bedrock](https://code.claude.com/docs/en/amazon-bedrock#4-pin-model-versions).

### GovCloud model pins

GovCloud profiles must keep pinning models in their `claude.json`, using `us-gov.` IDs.
Claude Code does switch its built-in defaults to the `us-gov.` prefix in `us-gov-*`
regions, but the GovCloud lineup trails commercial Bedrock, so those defaults can name
models GovCloud does not offer. For example, the `awsgov` profile pins `sonnet` to
`us-gov.anthropic.claude-sonnet-5` and, with no Haiku in GovCloud, pins `haiku` to the
same Sonnet model. The pins are also the model list that the `bedrock` feature's
entitlement check and `enable-govcloud-models.sh` read. Update them when GovCloud
adds a model.

See the [collection README](../../README.md) for the supported base, profiles, persistence, and release process.
