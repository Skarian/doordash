# DoorDash authentication operations

This directory owns the exe.dev VM integration around the upstream DoorDash
CLI. It is intentionally separate from `port/`, which owns only the Linux
binary build.

## Interactive login

Run:

```bash
bash ops/doordash-auth/mobile-login.sh
```

For compatibility, `bash port/mobile-login.sh` delegates here. Every launch
stops the previous interactive session, preserves the DoorDash identity cookie
while removing stale Chrome tab/window state, and raises one fresh OAuth
window in noVNC.

## Background renewal

`background-token-refresh.sh` runs OAuth in a private virtual display and
normally completes automatically through the durable DoorDash browser session.
The interactive and unattended paths share an exclusive lock and cannot use
the Chrome profile concurrently.

Install or refresh the unit definitions with:

```bash
sudo install -m 644 ops/doordash-auth/systemd/dd-cli-token-refresh.service \
  /etc/systemd/system/
sudo install -m 644 ops/doordash-auth/systemd/dd-cli-token-refresh.timer \
  /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now dd-cli-token-refresh.timer
```

The timer runs ten minutes after boot and then 48 hours after each renewal. If
DoorDash expires the browser identity cookie or requests verification, the
background service fails safely and the interactive flow must be run once.

## Runtime state

Runtime credentials do not belong in this workspace:

- `/home/exedev/.local/share/python_keyring/keyring_pass.cfg` stores the CLI
  token record and must remain mode `0600`.
- `/home/exedev/.local/share/dd-cli/chrome-profile` stores the durable browser
  identity session and must remain mode `0700`.

Never copy either location into build artifacts, vendor archives, logs, or
rollback bundles.
