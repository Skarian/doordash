# DoorDash CLI on Linux

This repository provides an unofficial Linux packaging of DoorDash's official
CLI payload plus provider-neutral authentication workflows for headless Linux
servers.

The Linux port, mobile browser, and token-renewal automation do not require a
specific hosting provider. Optional integrations can supply deployment-specific
URLs and service configuration without changing the core workflows.

## Layout

- `port/` — Linux binary build inputs and compatibility launchers.
- `workflows/auth/` — interactive OAuth, passwordless mobile noVNC, background
  renewal, and generic user-level systemd units.
- `integrations/` — optional hosting-provider configuration, including
  `integrations/exe-dev/`.
- `vendor/` — checksum-verified upstream releases used by the Linux port.
- `dist/` — validated Linux CLI binary.
- `.agents/skills/dd-cli-usage/` — DoorDash's agent usage instructions.
- `preferences/` — persistent user ordering preferences.

## CLI

The validated binary is available at `dist/dd-cli`. Install it somewhere on
your `PATH`, then authenticate:

```bash
install -m 755 dist/dd-cli "$HOME/.local/bin/dd-cli"
dd-cli login
```

See `port/README.md` for build details and `DD_CLI_UPDATE.md` before importing a
new upstream release.

## Mobile login on a Linux server

The mobile workflow runs Chrome inside a temporary X display and exposes noVNC
on the server's network interfaces:

```bash
bash workflows/auth/mobile-login.sh
```

By default it advertises `http://<LAN-address>:6080/`. The noVNC layer is
passwordless, so port 6080 must be limited to a trusted LAN, VPN, or
authenticated reverse proxy. The session replaces any older login session,
closes shortly after OAuth succeeds, and has a 15-minute maximum lifetime.

Set values in `~/.config/dd-cli-linux/auth.conf` or ordered fragments under
`~/.config/dd-cli-linux/auth.conf.d/`. Common settings include:

```bash
DD_MOBILE_BIND="0.0.0.0"
DD_MOBILE_PORT="6080"
DD_MOBILE_PUBLIC_URL="https://door.example.net/"
DD_MOBILE_MAX_SECONDS="900"
```

See `workflows/auth/README.md` for dependencies, loopback operation, and the
48-hour user systemd timer.

## Hosting integrations

Core workflows are hosting-provider neutral. Optional integrations currently
include:

- `integrations/exe-dev/` — advertises the VM's authenticated HTTPS proxy URL
  and enables the generic renewal timer.

Runtime tokens and browser identity data are stored outside the repository in
the user's XDG state/config directories.
