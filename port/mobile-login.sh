#!/usr/bin/env bash
set -euo pipefail

# Compatibility entrypoint. VM-specific authentication operations live outside
# the upstream-derived binary port so future port updates cannot overwrite them.
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec /bin/bash "$script_dir/../workflows/auth/mobile-login.sh" "$@"
