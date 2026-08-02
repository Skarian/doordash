#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/auth-common.sh"
dd_load_auth_config
dd_validate_auth_dependencies
dd_require_command x11vnc
dd_require_command websockify
dd_require_command xdotool

runtime_dir="$DD_AUTH_RUNTIME_BASE/mobile"
display_number="$DD_MOBILE_DISPLAY_NUMBER"
display_name=":${display_number}"

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

x11vnc -display "$display_name" -localhost -forever -shared -nopw \
    -rfbport "$DD_VNC_PORT" >"$runtime_dir/x11vnc.log" 2>&1 &
child_pids+=("$!")

websockify --web="$DD_NOVNC_DIR" \
    "${DD_MOBILE_BIND}:${DD_MOBILE_PORT}" "127.0.0.1:${DD_VNC_PORT}" \
    >"$runtime_dir/websockify.log" 2>&1 &
child_pids+=("$!")

env DISPLAY="$display_name" "$DD_CHROME_BIN" \
    --no-sandbox \
    --disable-dev-shm-usage \
    --no-first-run \
    --no-default-browser-check \
    --disable-session-crashed-bubble \
    --user-data-dir="$DD_OAUTH_PROFILE_DIR" \
    --start-maximized \
    --new-window \
    about:blank >"$runtime_dir/chrome.log" 2>&1 &
child_pids+=("$!")

sleep 2
timeout --signal=TERM --kill-after=10s "${DD_MOBILE_MAX_SECONDS}s" \
    env DISPLAY="$display_name" "$DD_CLI_BIN" login --verbose &
login_pid="$!"
child_pids+=("$login_pid")

raise_chrome_window "$display_name" || true
sleep 1
raise_chrome_window "$display_name" || true

set +e
wait "$login_pid"
login_status="$?"
set -e

if [[ "$login_status" -eq 0 ]]; then
    raise_chrome_window "$display_name" || true
    echo "DoorDash login completed. Closing the mobile desktop in ${DD_MOBILE_SUCCESS_GRACE_SECONDS}s."
    sleep "$DD_MOBILE_SUCCESS_GRACE_SECONDS"
    exit 0
fi

if [[ "$login_status" -eq 124 ]]; then
    echo "DoorDash mobile login expired after ${DD_MOBILE_MAX_SECONDS}s." >&2
fi
exit "$login_status"
