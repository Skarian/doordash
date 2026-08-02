# Authentication workflows

These workflows add headless and mobile OAuth support around `dd-cli` on a
normal Linux host. They have no hosting-provider dependency.

## Dependencies

The mobile workflow requires:

- Bash, systemd user services, `flock`, and `timeout`;
- Chrome, Google Chrome, or Chromium;
- Xvfb, Openbox, x11vnc, websockify, and xdotool;
- `dd-cli` on `PATH`, or an explicit `DD_CLI_BIN` setting.

## Interactive mobile login

Run:

```bash
bash workflows/auth/mobile-login.sh
```

The default listener is `0.0.0.0:6080` and the displayed URL uses the first
detected LAN IPv4 address. There is no VNC password. Only expose this temporary
desktop to a trusted network, VPN, or authenticated reverse proxy.

Use `DD_MOBILE_BIND=127.0.0.1` for SSH port-forwarding-only operation. The OAuth
callback itself always remains local to the browser running on the Linux host.

Each launch replaces the previous interactive service and browser. The service
stops shortly after successful OAuth and is forcibly stopped after 15 minutes.
Use `--foreground` on hosts without a running user systemd manager.

## Background renewal

DoorDash currently supplies a 72-hour access token without a refresh token.
`background-renewal.sh` therefore performs another OAuth authorization in a
private virtual display. A preserved browser identity session normally approves
it without interaction.

Install the generic 48-hour user timer:

```bash
bash workflows/auth/install-user-systemd.sh
```

For the timer to run while the account is logged out, enable systemd user
lingering according to your distribution's policy.

## Configuration

Configuration is sourced first from
`~/.config/dd-cli-linux/auth.conf`, followed lexically by `*.conf` files under
`~/.config/dd-cli-linux/auth.conf.d/`. This lets hosting integrations install a
contained fragment while users retain a later local override.
See `auth.conf.example` for the common settings.

State defaults to `~/.local/state/dd-cli-linux/`; runtime sockets, locks, and
logs use `$XDG_RUNTIME_DIR` when available. Neither location belongs in Git.
