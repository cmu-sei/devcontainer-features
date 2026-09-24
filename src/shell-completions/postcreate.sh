#!/bin/bash
## Regenerate completions for CLIs installed or upgraded after this feature's build
set -euo pipefail
bash "$(dirname "${BASH_SOURCE[0]}")/install-completions.sh" || echo "shell-completions: generation failed (continuing)" >&2
