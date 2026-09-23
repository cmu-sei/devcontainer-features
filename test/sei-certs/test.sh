#!/bin/bash
set -euo pipefail
# Every certificate the feature installed must be linked into the trust store. The loop
# reads the installed copies, so the test needs no edit when certificates are added or
# dropped; the count guards against an install that copied none.
shopt -s nullglob
certs=(/usr/local/share/ca-certificates/custom/*.crt)
test "${#certs[@]}" -gt 0
for cert in "${certs[@]}"; do
    test -e "/etc/ssl/certs/$(basename "$cert" .crt).pem"
done
test "$SSL_CERT_FILE" = /etc/ssl/certs/ca-certificates.crt
echo "Feature smoke test passed (${#certs[@]} certificate(s))."
