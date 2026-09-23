# SEI Certificates

Installs the SEI root CAs (RSA, ECDSA and kube, G4) and the Zscaler root CA into the system trust store with `update-ca-certificates`, and sets `NODE_EXTRA_CA_CERTS`, `REQUESTS_CA_BUNDLE`, `PIP_CERT` and `SSL_CERT_FILE` to the resulting bundle so Node, Python and pip trust outbound TLS through Zscaler.

Other features download software during the build, so list this one first in `overrideFeatureInstallOrder`:

```json
{
  "features": {
    "ghcr.io/cmu-sei/devcontainer-features/sei-certs:1": {}
  },
  "overrideFeatureInstallOrder": [
    "ghcr.io/cmu-sei/devcontainer-features/sei-certs"
  ]
}
```

To trust an additional root, install it in the base Dockerfile with `COPY` and `update-ca-certificates`.

See the [collection README](../../README.md) for the supported base, profiles, persistence, and release process.
