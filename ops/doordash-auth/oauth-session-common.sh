#!/usr/bin/env bash

# Shared process/profile handling for interactive and background DoorDash OAuth.
# Callers are expected to use `set -euo pipefail` themselves.

DD_OAUTH_PROFILE_DIR="${DD_OAUTH_PROFILE_DIR:-/home/exedev/.local/share/dd-cli/chrome-profile}"
DD_OAUTH_LOCK_FILE="${DD_OAUTH_LOCK_FILE:-/tmp/dd-cli-oauth-login.lock}"

terminate_profile_chrome() {
    local cmdline
    local pid
    local -a pids=()

    while IFS= read -r pid; do
        [[ -r "/proc/$pid/cmdline" ]] || continue
        cmdline="$(tr '\0' '\n' <"/proc/$pid/cmdline")"
        if grep -Fqx -- "--user-data-dir=${DD_OAUTH_PROFILE_DIR}" <<<"$cmdline"; then
            pids+=("$pid")
        fi
    done < <(
        {
            pgrep -u "$(id -u)" -x chrome || true
            pgrep -u "$(id -u)" -x google-chrome || true
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
    install -d -m 700 "$DD_OAUTH_PROFILE_DIR"

    # Chrome's session-restore files retain old tabs/windows independently of
    # cookies. Removing only those files gives each login a clean window while
    # preserving the DoorDash identity session used for automatic approval.
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
        cmdline="$(tr '\0' '\n' <"/proc/$pid/cmdline")"
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
            env DISPLAY="$display_name" xdotool search --onlyvisible --class 'Google-chrome' \
                2>/dev/null || true
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
