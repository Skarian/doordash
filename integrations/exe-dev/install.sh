#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../.." && pwd)"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/dd-cli-linux/auth.conf.d"
config_file="$config_dir/50-exe-dev.conf"
vm_name="${EXE_DEV_VM_NAME:-$(hostname -s)}"
mobile_port="${DD_MOBILE_PORT:-6080}"
legacy_profile="$HOME/.local/share/dd-cli/chrome-profile"

umask 077
mkdir -p "$config_dir"

{
    echo '# Managed by integrations/exe-dev/install.sh.'
    echo 'DD_AUTH_PROVIDER="${DD_AUTH_PROVIDER:-exe-dev}"'
    echo 'DD_MOBILE_BIND="${DD_MOBILE_BIND:-0.0.0.0}"'
    printf 'DD_MOBILE_PORT="${DD_MOBILE_PORT:-%s}"\n' "$mobile_port"
    printf 'DD_MOBILE_PUBLIC_URL="${DD_MOBILE_PUBLIC_URL:-https://%s.exe.xyz:%s/vnc.html?autoconnect=1&resize=scale}"\n' \
        "$vm_name" "$mobile_port"
    if [[ -d "$legacy_profile" ]]; then
        printf 'DD_OAUTH_PROFILE_DIR="${DD_OAUTH_PROFILE_DIR:-%s}"\n' "$legacy_profile"
    fi
} >"$config_file"
chmod 600 "$config_file"

bash "$repo_root/workflows/auth/install-user-systemd.sh"

echo
echo "Enabled exe.dev integration:"
echo "  config: $config_file"
echo "  mobile URL: https://${vm_name}.exe.xyz:${mobile_port}/vnc.html?autoconnect=1&resize=scale"

if command -v loginctl >/dev/null 2>&1; then
    linger="$(loginctl show-user "$USER" -p Linger --value 2>/dev/null || true)"
    if [[ "$linger" != "yes" ]]; then
        echo
        echo "Warning: user lingering is disabled. Run the following once so the"
        echo "renewal timer continues while you are logged out:"
        echo "  sudo loginctl enable-linger $USER"
    fi
fi
