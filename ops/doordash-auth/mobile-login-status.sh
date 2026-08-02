#!/usr/bin/env bash
set -euo pipefail

sudo systemctl --no-pager --lines=30 status dd-cli-mobile-login.service || true
sudo journalctl --no-pager -u dd-cli-mobile-login.service -n 40
