# Custom Certificates

Installs every root CA certificate (`*.crt`) in a folder inside the image into the system trust store with `update-ca-certificates`, and sets `NODE_EXTRA_CA_CERTS`, `REQUESTS_CA_BUNDLE`, `PIP_CERT` and `SSL_CERT_FILE` to the resulting bundle so Node, Python and pip trust outbound TLS through a TLS-inspecting proxy such as Zscaler. No certificates are bundled with the feature.

A feature installer sees only the image, not your project, so the base Dockerfile copies the certificates in first. With the Dockerfile in `.devcontainer/` (the default build context), put the `.crt` files in `.devcontainer/certs/` and add:

```dockerfile
COPY certs/ /usr/local/share/custom-certs/
```

Other features download software during the build, so list this one first in `overrideFeatureInstallOrder`:

```json
{
  "build": { "dockerfile": "Dockerfile" },
  "features": {
    "ghcr.io/cmu-sei/devcontainer-features/custom-certs:1": {}
  },
  "overrideFeatureInstallOrder": [
    "ghcr.io/cmu-sei/devcontainer-features/custom-certs"
  ]
}
```

| Option | Default | Description |
| --- | --- | --- |
| `folder` | `/usr/local/share/custom-certs` | Folder inside the image holding the `*.crt` files. |

Only files ending in `.crt` are installed, since `update-ca-certificates` ignores any other extension; rename a PEM-encoded `.pem` to `.crt`. An empty or missing folder prints a warning and the build continues.

See the [collection README](../../README.md) for the supported base, profiles, persistence, and release process.
