# DoorDash CLI for Linux

Use DoorDash from the command line to search restaurants and stores, browse
menus, manage carts, place orders, and check delivery status.

This repository packages DoorDash's official CLI for x86-64 Linux. It also
includes login helpers for remote and headless servers.

> This is an unofficial Linux distribution of the DoorDash CLI. A DoorDash
> account with CLI access is required.

Linux artifacts use the same version number as the packaged upstream DoorDash
CLI release.

## Install

From a checkout of this repository:

```bash
install -Dm755 dist/dd-cli "$HOME/.local/bin/dd-cli"
dd-cli --version
```

Make sure `$HOME/.local/bin` is on your `PATH`.

## Sign in

On a Linux desktop:

```bash
dd-cli login
```

Complete the DoorDash sign-in flow in the browser, then use `dd-cli --help` to
explore the available commands.

## Sign in to a remote server

For a remote or headless server:

```bash
bash workflows/auth/mobile-login.sh
```

Open the displayed URL from a phone or another computer and complete the
DoorDash login. The temporary browser session closes after authentication and
has a 15-minute maximum lifetime.

Port 6080 provides a passwordless browser session. Restrict it to a trusted
local network, VPN, or authenticated reverse proxy.

See [workflows/auth/README.md](workflows/auth/README.md) for dependencies,
configuration, SSH-forwarding mode, and troubleshooting.

## Keep the session active

DoorDash access tokens currently last 72 hours and require another OAuth
authorization to renew. This repository includes a user-level systemd timer
that reauthorizes every 48 hours using the saved browser session:

```bash
bash workflows/auth/install-user-systemd.sh
```

Run the interactive mobile login if automatic authorization needs attention.

## Configuration

Authentication settings live in:

```text
~/.config/dd-cli-linux/auth.conf
~/.config/dd-cli-linux/auth.conf.d/*.conf
```

Start with
[workflows/auth/auth.conf.example](workflows/auth/auth.conf.example).

Runtime credentials and browser profiles live under the user's XDG data and
state directories.

## Building the Linux executable

The Linux build combines the unchanged DoorDash application payload from the
official release with a Linux-native CPython and PyInstaller runtime:

```bash
bash port/build.sh
```

Build details, dependencies, provenance, and keyring behavior are documented in
[port/README.md](port/README.md).

Before importing a newer DoorDash release, follow
[DD_CLI_UPDATE.md](DD_CLI_UPDATE.md). It documents the checksum, payload
verification, authentication-state boundaries, and validation checklist.

## Integrations

Integrations provide setup for particular hosting environments. Available
integrations:

- [exe.dev](integrations/exe-dev/README.md) — configures the authenticated HTTPS
  proxy URL for remote login and installs the authorization-renewal timer.

## Security

On headless machines, the default launcher uses a file-based plaintext keyring.
Keep its permissions restricted to the current user. Use a secure Linux keyring
backend on shared or untrusted systems, and treat browser profiles and
authentication logs as secrets.
