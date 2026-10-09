# Certificates

Put root CA certificates here, one per file, ending in `.crt` (PEM-encoded; rename a
`.pem` to `.crt`). The Dockerfile copies this folder into the image and the
`custom-certs` feature adds every `*.crt` to the system trust store, before any other
feature downloads anything. This is what a TLS-inspecting proxy such as Zscaler needs.

Rebuild the container after adding or removing a certificate. Root CA certificates are
public, so committing them is safe; never put a private key here.
