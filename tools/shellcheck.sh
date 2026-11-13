#!/bin/bash
# Run ShellCheck (warnings and errors) over every tracked shell script.
# Set SHELLCHECK to use a local binary instead of the pinned container image.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -n "${SHELLCHECK:-}" ]; then
    sc=("$SHELLCHECK")
else
    sc=(docker run --rm -v "$PWD:/mnt:ro" -w /mnt koalaman/shellcheck:v0.11.0)
fi

# src/*/org-*.sh are byte-for-byte copies of tools/lib/*.sh (sync-library.py --check enforces it),
# so only the originals are checked. Extensionless scripts are found by their shebang.
scripts=()
libs=()
while IFS= read -r -d '' f; do
    case "$f" in
        src/*/org-*.sh) ;;
        tools/lib/*.sh) libs+=("$f") ;;
        *.sh) scripts+=("$f") ;;
        *) if head -n1 "$f" | grep -Eq '^#!.*(ba)?sh'; then scripts+=("$f"); fi ;;
    esac
done < <(git ls-files -z)

status=0
"${sc[@]}" -S warning "${scripts[@]}" || status=1
# The libraries are sourced: variables they set are read by the scripts that source them.
"${sc[@]}" -S warning -e SC2034 "${libs[@]}" || status=1
[ "$status" = 0 ] && echo "ShellCheck passed: $(( ${#scripts[@]} + ${#libs[@]} )) scripts."
exit "$status"
