#!/bin/bash
set -euo pipefail
# The default build has no certificates (the base image has no /usr/local/share/custom-certs),
# so this checks the environment and that whatever was installed got linked; the
# with_certs scenario checks the install itself.
shopt -s nullglob
for cert in /usr/local/share/ca-certificates/custom/*.crt; do
    test -e "/etc/ssl/certs/$(basename "$cert" .crt).pem"
done
test "$SSL_CERT_FILE" = /etc/ssl/certs/ca-certificates.crt
test "$NODE_EXTRA_CA_CERTS" = /etc/ssl/certs/ca-certificates.crt
echo "Feature smoke test passed."
