#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/auth-common.sh"
dd_load_auth_config

unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
service_template="$script_dir/systemd/user/dd-cli-auth-renewal.service.in"
timer_template="$script_dir/systemd/user/dd-cli-auth-renewal.timer"
service_target="$unit_dir/dd-cli-auth-renewal.service"
timer_target="$unit_dir/dd-cli-auth-renewal.timer"

mkdir -p "$unit_dir"

escaped_script="${script_dir//\/\\}/background-renewal.sh"
escaped_script="${escaped_script//&/\\&}"
escaped_script="${escaped_script//|/\\|}"
sed "s|@BACKGROUND_RENEWAL_SCRIPT@|$escaped_script|g" \
    "$service_template" >"$service_target"
chmod 644 "$service_target"
install -m 644 "$timer_template" "$timer_target"

systemctl --user daemon-reload
systemctl --user enable --now dd-cli-auth-renewal.timer

echo "Installed user units:"
echo "  $service_target"
echo "  $timer_target"
systemctl --user list-timers dd-cli-auth-renewal.timer --all --no-pager
