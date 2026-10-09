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

Each container start runs `claude update` in the background unless `version` pins a release;
see [Versions and updates](../../README.md#versions-and-updates).
| `bedrock` | `false` | Use Amazon Bedrock. Writes `CLAUDE_CODE_USE_BEDROCK=1` into `~/.claude/settings.json` `env`. Bedrock still needs `AWS_REGION` and credentials from the container. |

## Bedrock model pins

When the `bedrock` option is on, or `CLAUDE_CODE_USE_BEDROCK` is set (to anything
except `0` or `false`), each create writes the `/model` tier pins in [bedrock-models.json](bedrock-models.json)
into `~/.claude/settings.json` `env`. Otherwise Claude Code picks its own Bedrock
default for each tier, and that default can trail the newest enabled model.

| Variable | Pinned model |
| --- | --- |
| `ANTHROPIC_DEFAULT_FABLE_MODEL` | `us.anthropic.claude-fable-5-1` |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | `us.anthropic.claude-opus-5-5` |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | `us.anthropic.claude-sonnet-5-5` |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | `us.anthropic.claude-haiku-4-5-20251001-v1:0` |

A variable already set in the container environment is left alone. A profile's
`claude.json` is merged afterwards, so its pins win (GovCloud profiles must supply
their own `us-gov.` IDs). Bump these pins, and the feature version, when newer
models ship.

See the [collection README](../../README.md) for the supported base, profiles, persistence, and release process.
