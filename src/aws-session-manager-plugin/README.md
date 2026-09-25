# AWS Session Manager plugin

Installs the AWS Session Manager plugin for aws ssm start-session, along with the AWS CLI it extends.

```json
{
  "features": {
    "ghcr.io/cmu-sei/devcontainer-features/aws-session-manager-plugin:1": {}
  }
}
```

The plugin is a Debian package pinned by version and SHA-256 in `release.json`, for
`amd64` and `arm64`.

The AWS CLI and its bash and zsh completions come from
`ghcr.io/devcontainers/features/aws-cli:1`, which this feature depends on with default
options. To pin the CLI version, list that feature yourself and set `version` there.

See the [collection README](../../README.md) for the supported base, profiles, persistence, and release process.
