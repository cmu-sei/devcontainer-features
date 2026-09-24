#!/bin/bash
# Trust local CAs in Chromium, which reads the user's NSS database rather than the system store.
set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/org-runtime.sh"

OPTIONS="$(dirname "${BASH_SOURCE[0]}")/options.env"
option() { [ -f "$OPTIONS" ] || return 0; sed -n "s/^$1=//p" "$OPTIONS" | tail -n 1; }
[ "$(option TRUSTLOCALCAS)" != false ] || exit 0
command -v certutil >/dev/null || { echo "playwright: certutil not found; skipping Chromium CA trust." >&2; exit 0; }

# postSTART rather than postCreate: a project's own postCreate may generate or install CAs
# (for example a dev TLS certificate), and every postCreate finishes before postStart. It also
# re-syncs after CAs change without a rebuild.
CA_DIR=/usr/local/share/ca-certificates
NSSDB="$HOME/.pki/nssdb"
STATE="$NSSDB/org-playwright-cas"
mkdir -p "$NSSDB"
[ -f "$NSSDB/cert9.db" ] || certutil -N -d "sql:$NSSDB" --empty-password

# Replace what the previous start imported, so a CA removed from the system goes away here too.
# Certificates added by other means are not touched.
if [ -f "$STATE" ]; then
    while IFS= read -r nickname; do
        certutil -D -d "sql:$NSSDB" -n "$nickname" >/dev/null 2>&1 || true
    done < "$STATE"
fi
: > "$STATE.tmp"
while IFS= read -r -d '' cert; do
    nickname="${cert#"$CA_DIR"/}"
    if certutil -A -d "sql:$NSSDB" -n "$nickname" -t "C,," -i "$cert"; then
        printf '%s\n' "$nickname" >> "$STATE.tmp"
    fi
done < <(find "$CA_DIR" -type f -name '*.crt' -print0 2>/dev/null | sort -z)
mv "$STATE.tmp" "$STATE"
