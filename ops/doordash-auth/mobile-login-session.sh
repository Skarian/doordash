#!/usr/bin/env bash
set -euo pipefail

runtime_dir="/tmp/dd-cli-mobile-login"
display_number="99"
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

Xvfb "$display_name" -screen 0 1280x800x24 -nolisten tcp &
child_pids+=("$!")

for _ in {1..100}; do
    [[ -S "/tmp/.X11-unix/X${display_number}" ]] && break
    sleep 0.1
done

env DISPLAY="$display_name" openbox &
child_pids+=("$!")

x11vnc -display "$display_name" -localhost -forever -shared \
    -nopw -rfbport 5900 &
child_pids+=("$!")

websockify --web=/home/exedev/workspace/ops/doordash-auth/novnc/ \
    0.0.0.0:6080 127.0.0.1:5900 &
child_pids+=("$!")

env DISPLAY="$display_name" google-chrome-stable \
    --no-sandbox \
    --disable-dev-shm-usage \
    --no-first-run \
    --no-default-browser-check \
    --disable-session-crashed-bubble \
    --user-data-dir="$DD_OAUTH_PROFILE_DIR" \
    --start-maximized \
    --new-window \
    about:blank &
child_pids+=("$!")

sleep 2
env DISPLAY="$display_name" dd-cli login --verbose &
login_pid="$!"
child_pids+=("$login_pid")

raise_chrome_window "$display_name" || true
sleep 1
raise_chrome_window "$display_name" || true

wait "$login_pid"
raise_chrome_window "$display_name" || true

echo "DoorDash login completed. Keeping the remote desktop available."
wait
