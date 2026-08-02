#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${XDG_RUNTIME_DIR:-}" && -d "/run/user/$(id -u)" ]]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi

systemctl --user --no-pager --lines=30 status dd-cli-mobile-login.service || true
journalctl --user --no-pager -u dd-cli-mobile-login.service -n 40
