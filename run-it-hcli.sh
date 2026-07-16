#!/usr/bin/env bash
# Local runner — same as ci-hcli-tests.sh (uses PATH hcli or bin/hcli-linux).
set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ci-hcli-tests.sh" "$@"
