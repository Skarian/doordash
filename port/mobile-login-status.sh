#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec /bin/bash "$script_dir/../workflows/auth/mobile-login-status.sh" "$@"
