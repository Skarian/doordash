#!/usr/bin/env bash

# Provider-neutral configuration and process handling for DoorDash OAuth.
# Callers are expected to enable their preferred shell safety options.

DD_AUTH_WORKFLOW_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

dd_load_auth_config() {
    local config_dir
    local config_file
    local -a config_fragments=()

    if [[ -z "${XDG_RUNTIME_DIR:-}" && -d "/run/user/$(id -u)" ]]; then
        XDG_RUNTIME_DIR="/run/user/$(id -u)"
        export XDG_RUNTIME_DIR
    fi

    config_dir="${DD_AUTH_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/dd-cli-linux}"
    config_file="${DD_AUTH_CONFIG_FILE:-$config_dir/auth.conf}"

    if [[ -r "$config_file" ]]; then
        # shellcheck disable=SC1090
        source "$config_file"
    fi

    if [[ -d "$config_dir/auth.conf.d" ]]; then
        shopt -s nullglob
        config_fragments=("$config_dir"/auth.conf.d/*.conf)
        shopt -u nullglob
        for config_file in "${config_fragments[@]}"; do
            # shellcheck disable=SC1090
            source "$config_file"
        done
    fi

    DD_AUTH_CONFIG_HOME="$config_dir"
    DD_AUTH_STATE_DIR="${DD_AUTH_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/dd-cli-linux}"
    DD_AUTH_RUNTIME_BASE="${DD_AUTH_RUNTIME_BASE:-${XDG_RUNTIME_DIR:-/tmp}/dd-cli-linux-$(id -u)}"
    DD_OAUTH_PROFILE_DIR="${DD_OAUTH_PROFILE_DIR:-$DD_AUTH_STATE_DIR/chrome-profile}"
    DD_OAUTH_LOCK_FILE="${DD_OAUTH_LOCK_FILE:-$DD_AUTH_RUNTIME_BASE/oauth.lock}"

    DD_MOBILE_BIND="${DD_MOBILE_BIND:-0.0.0.0}"
    DD_MOBILE_PORT="${DD_MOBILE_PORT:-6080}"
    DD_VNC_PORT="${DD_VNC_PORT:-5900}"
    DD_MOBILE_DISPLAY_NUMBER="${DD_MOBILE_DISPLAY_NUMBER:-99}"
    DD_BACKGROUND_DISPLAY_NUMBER="${DD_BACKGROUND_DISPLAY_NUMBER:-98}"
    DD_MOBILE_MAX_SECONDS="${DD_MOBILE_MAX_SECONDS:-900}"
    DD_MOBILE_SUCCESS_GRACE_SECONDS="${DD_MOBILE_SUCCESS_GRACE_SECONDS:-10}"
    DD_BACKGROUND_LOGIN_TIMEOUT_SECONDS="${DD_BACKGROUND_LOGIN_TIMEOUT_SECONDS:-180}"
    DD_NOVNC_DIR="${DD_NOVNC_DIR:-$DD_AUTH_WORKFLOW_DIR/novnc}"

    DD_CLI_BIN="${DD_CLI_BIN:-$(command -v dd-cli 2>/dev/null || true)}"
    if [[ -z "$DD_CLI_BIN" && -x "$HOME/.local/bin/dd-cli" ]]; then
        DD_CLI_BIN="$HOME/.local/bin/dd-cli"
    fi
    DD_CHROME_BIN="${DD_CHROME_BIN:-$(command -v google-chrome-stable 2>/dev/null || command -v google-chrome 2>/dev/null || command -v chromium 2>/dev/null || true)}"

    export DD_AUTH_CONFIG_HOME DD_AUTH_STATE_DIR DD_AUTH_RUNTIME_BASE
    export DD_OAUTH_PROFILE_DIR DD_OAUTH_LOCK_FILE DD_CLI_BIN DD_CHROME_BIN
    export DD_MOBILE_BIND DD_MOBILE_PORT DD_VNC_PORT DD_MOBILE_DISPLAY_NUMBER
    export DD_BACKGROUND_DISPLAY_NUMBER DD_MOBILE_MAX_SECONDS
    export DD_MOBILE_SUCCESS_GRACE_SECONDS DD_BACKGROUND_LOGIN_TIMEOUT_SECONDS
    export DD_NOVNC_DIR
}

dd_require_command() {
    local command_name="$1"
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "error: required command not found: $command_name" >&2
        return 1
    fi
}

dd_validate_auth_dependencies() {
    [[ -n "$DD_CLI_BIN" && -x "$DD_CLI_BIN" ]] || {
        echo "error: dd-cli was not found; set DD_CLI_BIN to its absolute path" >&2
        return 1
    }
    [[ -n "$DD_CHROME_BIN" && -x "$DD_CHROME_BIN" ]] || {
        echo "error: Chrome or Chromium was not found; set DD_CHROME_BIN" >&2
        return 1
    }

    local command_name
    for command_name in Xvfb openbox flock timeout; do
        dd_require_command "$command_name"
    done
}

dd_detect_lan_ipv4() {
    local address
    address="$(
        ip -o -4 addr show scope global 2>/dev/null \
            | awk '{sub(/\/.*/, "", $4); print $4; exit}'
    )"
    if [[ -n "$address" ]]; then
        printf '%s\n' "$address"
    else
        printf '%s\n' "127.0.0.1"
    fi
}

dd_mobile_url() {
    if [[ -n "${DD_MOBILE_PUBLIC_URL:-}" ]]; then
        printf '%s\n' "$DD_MOBILE_PUBLIC_URL"
        return 0
    fi

    local address
    case "$DD_MOBILE_BIND" in
        0.0.0.0) address="$(dd_detect_lan_ipv4)" ;;
        localhost) address="127.0.0.1" ;;
        *) address="$DD_MOBILE_BIND" ;;
    esac
    printf 'http://%s:%s/vnc.html?autoconnect=1&resize=scale\n' \
        "$address" "$DD_MOBILE_PORT"
}

terminate_profile_chrome() {
    local cmdline
    local pid
    local -a pids=()

    while IFS= read -r pid; do
        [[ -r "/proc/$pid/cmdline" ]] || continue
        cmdline="$(tr '\0' '\n' <"/proc/$pid/cmdline" 2>/dev/null || true)"
        if grep -Fqx -- "--user-data-dir=${DD_OAUTH_PROFILE_DIR}" <<<"$cmdline"; then
            pids+=("$pid")
        fi
    done < <(
        {
            pgrep -u "$(id -u)" -x chrome || true
            pgrep -u "$(id -u)" -x chromium || true
        } | sort -un
    )
    ((${#pids[@]})) || return 0

    kill "${pids[@]}" 2>/dev/null || true
    for _ in {1..50}; do
        local -a remaining=()
        for pid in "${pids[@]}"; do
            kill -0 "$pid" 2>/dev/null && remaining+=("$pid")
        done
        ((${#remaining[@]} == 0)) && return 0
        pids=("${remaining[@]}")
        sleep 0.1
    done

    kill -KILL "${pids[@]}" 2>/dev/null || true
}

prepare_oauth_profile() {
    install -d -m 700 "$DD_AUTH_STATE_DIR" "$DD_OAUTH_PROFILE_DIR"

    # Remove only saved window/tab state. Cookies and the DoorDash identity
    # session remain available for automatic OAuth authorization.
    local sessions_dir="$DD_OAUTH_PROFILE_DIR/Default/Sessions"
    if [[ -d "$sessions_dir" ]]; then
        find "$sessions_dir" -mindepth 1 -maxdepth 1 -type f -delete
    fi

    rm -f \
        "$DD_OAUTH_PROFILE_DIR/SingletonCookie" \
        "$DD_OAUTH_PROFILE_DIR/SingletonLock" \
        "$DD_OAUTH_PROFILE_DIR/SingletonSocket"
}

stop_stale_display() {
    local cmdline
    local display_number="$1"
    local pid
    local -a pids=()

    while IFS= read -r pid; do
        [[ -r "/proc/$pid/cmdline" ]] || continue
        cmdline="$(tr '\0' '\n' <"/proc/$pid/cmdline" 2>/dev/null || true)"
        if grep -Fqx -- ":${display_number}" <<<"$cmdline"; then
            pids+=("$pid")
        fi
    done < <(pgrep -u "$(id -u)" -x Xvfb || true)

    if ((${#pids[@]})); then
        kill "${pids[@]}" 2>/dev/null || true
        for _ in {1..30}; do
            local alive=false
            for pid in "${pids[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    alive=true
                    break
                fi
            done
            [[ "$alive" == false ]] && break
            sleep 0.1
        done
    fi

    rm -f "/tmp/.X${display_number}-lock" "/tmp/.X11-unix/X${display_number}"
}

raise_chrome_window() {
    local display_name="$1"
    local old_window
    local window_id=""
    local -a windows=()

    for _ in {1..80}; do
        mapfile -t windows < <(
            {
                env DISPLAY="$display_name" xdotool search --onlyvisible --class 'Google-chrome' \
                    2>/dev/null || true
                env DISPLAY="$display_name" xdotool search --onlyvisible --class 'Chromium' \
                    2>/dev/null || true
            } | sort -un
        )
        if ((${#windows[@]})); then
            window_id="${windows[-1]}"
            for old_window in "${windows[@]}"; do
                [[ "$old_window" == "$window_id" ]] && continue
                env DISPLAY="$display_name" xdotool windowclose "$old_window" \
                    2>/dev/null || true
            done
            env DISPLAY="$display_name" xdotool windowraise "$window_id" 2>/dev/null || true
            env DISPLAY="$display_name" xdotool windowactivate --sync "$window_id" \
                2>/dev/null || true
            return 0
        fi
        sleep 0.1
    done

    return 1
}
