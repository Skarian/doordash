#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/auth-common.sh"
dd_load_auth_config
dd_validate_auth_dependencies
dd_require_command x11vnc
dd_require_command websockify
dd_require_command xdotool

unit_name="dd-cli-mobile-login"
renewal_unit_name="dd-cli-auth-renewal"
session_script="$script_dir/mobile-login-session.sh"
foreground=false

case "${1:-}" in
    "") ;;
    --foreground) foreground=true ;;
    -h|--help)
        cat <<'EOF'
Usage: mobile-login.sh [--foreground]

Starts a temporary, passwordless noVNC browser for DoorDash OAuth. By default
the browser runs in a transient user systemd unit. Use --foreground when user
systemd is unavailable.
EOF
        exit 0
        ;;
    *)
        echo "error: unknown option: $1" >&2
        exit 2
        ;;
esac

mobile_url="$(dd_mobile_url)"

echo "Mobile login desktop:"
echo "  $mobile_url"
echo
echo "This passwordless session listens on ${DD_MOBILE_BIND}:${DD_MOBILE_PORT}."
echo "It closes ${DD_MOBILE_SUCCESS_GRACE_SECONDS}s after success and after"
echo "${DD_MOBILE_MAX_SECONDS}s at the latest. Restrict the port to a trusted"
echo "network, VPN, or authenticated reverse proxy."
echo

if [[ "$foreground" == true ]] || ! systemctl --user show-environment >/dev/null 2>&1; then
    exec /bin/bash "$session_script"
fi

systemctl --user stop "$unit_name.service" 2>/dev/null || true
systemctl --user stop "$renewal_unit_name.service" 2>/dev/null || true
systemctl --user reset-failed "$unit_name.service" 2>/dev/null || true

systemd-run --user \
    --unit="$unit_name" \
    --collect \
    --property="RuntimeMaxSec=${DD_MOBILE_MAX_SECONDS}s" \
    --setenv="DD_AUTH_CONFIG_HOME=$DD_AUTH_CONFIG_HOME" \
    --setenv="DD_AUTH_STATE_DIR=$DD_AUTH_STATE_DIR" \
    --setenv="DD_AUTH_RUNTIME_BASE=$DD_AUTH_RUNTIME_BASE" \
    --setenv="DD_OAUTH_PROFILE_DIR=$DD_OAUTH_PROFILE_DIR" \
    --setenv="DD_OAUTH_LOCK_FILE=$DD_OAUTH_LOCK_FILE" \
    --setenv="DD_CLI_BIN=$DD_CLI_BIN" \
    --setenv="DD_CHROME_BIN=$DD_CHROME_BIN" \
    --setenv="DD_MOBILE_BIND=$DD_MOBILE_BIND" \
    --setenv="DD_MOBILE_PORT=$DD_MOBILE_PORT" \
    --setenv="DD_VNC_PORT=$DD_VNC_PORT" \
    --setenv="DD_MOBILE_DISPLAY_NUMBER=$DD_MOBILE_DISPLAY_NUMBER" \
    --setenv="DD_MOBILE_MAX_SECONDS=$DD_MOBILE_MAX_SECONDS" \
    --setenv="DD_MOBILE_SUCCESS_GRACE_SECONDS=$DD_MOBILE_SUCCESS_GRACE_SECONDS" \
    --setenv="DD_NOVNC_DIR=$DD_NOVNC_DIR" \
    /bin/bash "$session_script"

sleep 2
echo "Service state: $(systemctl --user is-active "$unit_name.service" 2>/dev/null || true)"
