# DoorDash authentication on Linux servers

These scripts run the DoorDash browser sign-in flow on a remote or headless
Linux machine. They provide an interactive browser reachable from another
device and a timer that renews authorization every 48 hours.

## Requirements

The interactive login requires:

- Bash, `flock`, and `timeout`;
- a running systemd user manager, or foreground mode;
- Chrome, Google Chrome, or Chromium;
- Xvfb, Openbox, x11vnc, websockify, and xdotool; and
- `dd-cli` on `PATH`, or `DD_CLI_BIN` set to its absolute path.

## Sign in from another device

Run from the repository root:

```bash
bash workflows/auth/mobile-login.sh
```

Open the displayed URL on a phone or computer and complete the DoorDash login.
Each launch replaces the previous login session, starts a fresh temporary
desktop, and brings the current Chrome window to the foreground. The service
closes 10 seconds after successful authentication and has a 15-minute maximum
lifetime.

The default listener is a passwordless noVNC session on `0.0.0.0:6080` and the
displayed URL uses the first detected LAN IPv4 address. Restrict port 6080 to a
trusted network, VPN, or authenticated reverse proxy.

Use foreground mode when a systemd user manager is unavailable:

```bash
bash workflows/auth/mobile-login.sh --foreground
```

Check the current session with:

```bash
bash workflows/auth/mobile-login-status.sh
```

## Use an SSH tunnel

Set the listener to loopback in `~/.config/dd-cli-linux/auth.conf`:

```bash
DD_MOBILE_BIND="127.0.0.1"
```

Forward the port from another computer:

```bash
ssh -L 6080:127.0.0.1:6080 user@server
```

Then open `http://127.0.0.1:6080/vnc.html?autoconnect=1&resize=scale`.

## Renew authorization automatically

DoorDash access tokens currently last 72 hours and require another OAuth
authorization to renew. The renewal workflow opens the login flow in a private
virtual display and uses the saved Chrome identity session for approval.

Install and start the 48-hour user timer:

```bash
bash workflows/auth/install-user-systemd.sh
```

Enable user lingering when the timer must run after logout:

```bash
sudo loginctl enable-linger "$USER"
```

Inspect the timer and its most recent service run with:

```bash
systemctl --user list-timers dd-cli-auth-renewal.timer --all
systemctl --user status dd-cli-auth-renewal.service
```

Run the interactive login again if automatic approval needs attention.

## Configuration

Start with [auth.conf.example](auth.conf.example). Settings are loaded in this
order:

1. `~/.config/dd-cli-linux/auth.conf`
2. `~/.config/dd-cli-linux/auth.conf.d/*.conf`, in lexical order

Common settings include:

| Setting | Default | Purpose |
| --- | --- | --- |
| `DD_MOBILE_BIND` | `0.0.0.0` | noVNC listener address |
| `DD_MOBILE_PORT` | `6080` | noVNC listener port |
| `DD_MOBILE_PUBLIC_URL` | detected LAN URL | URL printed for the user |
| `DD_MOBILE_MAX_SECONDS` | `900` | interactive session lifetime |
| `DD_MOBILE_SUCCESS_GRACE_SECONDS` | `10` | delay before closing after login |
| `DD_CLI_BIN` | discovered from `PATH` | DoorDash CLI executable |
| `DD_CHROME_BIN` | automatically detected | Chrome or Chromium executable |

State defaults to `~/.local/state/dd-cli-linux/`. Runtime sockets, locks, and
logs use `$XDG_RUNTIME_DIR` when available. Keep the Chrome profile, keyring,
and authentication logs restricted to the current user.
