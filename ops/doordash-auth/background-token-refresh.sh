#!/usr/bin/env bash
set -euo pipefail

runtime_dir="/tmp/dd-cli-background-refresh"
display_number="98"
display_name=":${display_number}"
common_script="/home/exedev/workspace/ops/doordash-auth/oauth-session-common.sh"

source "$common_script"

umask 077
mkdir -p "$runtime_dir"

exec 9>"$DD_OAUTH_LOCK_FILE"
flock -w 300 9

terminate_profile_chrome
prepare_oauth_profile
stop_stale_display "$display_number"

child_pids=()
cleanup() {
    if ((${#child_pids[@]})); then
        kill "${child_pids[@]}" 2>/dev/null || true
    fi
    terminate_profile_chrome
}
trap cleanup EXIT INT TERM

Xvfb "$display_name" -screen 0 1280x800x24 -nolisten tcp \
    >"$runtime_dir/xvfb.log" 2>&1 &
child_pids+=("$!")

for _ in {1..100}; do
    [[ -S "/tmp/.X11-unix/X${display_number}" ]] && break
    sleep 0.1
done
[[ -S "/tmp/.X11-unix/X${display_number}" ]]

env DISPLAY="$display_name" openbox >"$runtime_dir/openbox.log" 2>&1 &
child_pids+=("$!")

env DISPLAY="$display_name" google-chrome-stable \
    --no-sandbox \
    --disable-dev-shm-usage \
    --no-first-run \
    --no-default-browser-check \
    --disable-session-crashed-bubble \
    --user-data-dir="$DD_OAUTH_PROFILE_DIR" \
    --new-window \
    about:blank >"$runtime_dir/chrome.log" 2>&1 &
child_pids+=("$!")

sleep 2
timeout --signal=TERM --kill-after=10s 180s \
    env DISPLAY="$display_name" dd-cli login \
    >"$runtime_dir/login.log" 2>&1

echo "DoorDash access token renewed successfully."
