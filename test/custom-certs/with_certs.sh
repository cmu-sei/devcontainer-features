#!/bin/bash
set -euo pipefail
# Debian's Mozilla roots stand in for a project's certificates: a real folder of *.crt
# files that every Debian base already has.
shopt -s nullglob
source=(/usr/share/ca-certificates/mozilla/*.crt)
installed=(/usr/local/share/ca-certificates/custom/*.crt)
test "${#installed[@]}" -gt 0
test "${#installed[@]}" -eq "${#source[@]}"
for cert in "${installed[@]}"; do
    test -e "/etc/ssl/certs/$(basename "$cert" .crt).pem"
done
echo "Scenario passed (${#installed[@]} certificates)."
