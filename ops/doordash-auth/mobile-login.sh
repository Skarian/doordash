#!/usr/bin/env bash
set -euo pipefail

unit_name="dd-cli-mobile-login"
refresh_unit_name="dd-cli-token-refresh"
session_script="/home/exedev/workspace/ops/doordash-auth/mobile-login-session.sh"
novnc_port="6080"

# Replace the old interactive browser session every time. Also stop an
# in-flight background renewal so both paths cannot contend for the profile.
sudo systemctl stop "$unit_name.service" 2>/dev/null || true
sudo systemctl stop "$refresh_unit_name.service" 2>/dev/null || true
sudo systemctl reset-failed "$unit_name.service" 2>/dev/null || true

sudo systemd-run \
    --unit="$unit_name" \
    --collect \
    --uid=exedev \
    --gid=exedev \
    --setenv=HOME=/home/exedev \
    --setenv=PATH=/home/exedev/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    /bin/bash "$session_script"

sleep 2

echo "Mobile login desktop:"
echo "  https://doordash.exe.xyz:${novnc_port}/vnc.html?autoconnect=1&resize=scale"
echo
echo "Service status:"
sudo systemctl --no-pager --lines=5 status "$unit_name.service" || true
