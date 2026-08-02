#!/usr/bin/env bash
set -euo pipefail

# Compatibility entrypoint. VM-specific authentication operations live outside
# the upstream-derived binary port so future port updates cannot overwrite them.
exec /bin/bash /home/exedev/workspace/ops/doordash-auth/mobile-login.sh "$@"
