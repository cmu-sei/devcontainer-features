#!/bin/bash
set -euo pipefail
for name in sei-ecdsa-root-ca-g4 sei-rsa-kube-root-ca-g4 sei-rsa-root-ca-g4 zscaler-ca; do
    test -f "/usr/local/share/ca-certificates/custom/$name.crt"
    test -e "/etc/ssl/certs/$name.pem"
done
test "$SSL_CERT_FILE" = /etc/ssl/certs/ca-certificates.crt
echo "Feature smoke test passed."
