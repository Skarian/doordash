# DoorDash CLI workspace

This is a small local integration around DoorDash's official native Linux CLI.
It does not rebuild, repackage, or publish DoorDash software.

The pinned release is `v0.2.4` for Linux x86-64. Its URL and SHA-256 checksum
live in `release.env`.

## Install or reinstall

```bash
./install.sh
dd-cli --version
```

Requires Bash, Python 3.12+, and `flock` (provided on this VM). The installer
downloads and verifies the official archive in memory, installs its complete bundle under
`~/.local/lib/dd-cli/<version>/`, and points `~/.local/bin/dd-cli` directly at
the native executable. Existing version directories are retained until housekeeping;
neither the archive nor an extracted application is stored in this repository.

## Authentication on this headless VM

The native CLI now uses Linux Secret Service to retain both access and refresh
tokens. Native login, authenticated reads, real automatic renewal/retry,
and automatic unlock after a full VM reboot have passed. The old token
helpers and expired access-token file have been removed.

No VNC, resident browser, or custom renewal timer is required. DoorDash's
unchanged CLI performs renewal; the standard keyring service stores credentials.

From Android/Termux, connect with a localhost callback tunnel:

```bash
ssh -o ExitOnForwardFailure=yes -L 4180:127.0.0.1:4180 doordash.exe.xyz
```

Then run this **inside that SSH session**:

```bash
env -u DD_CLI_ACCESS_TOKEN BROWSER=true dd-cli login
```

Open the printed authorization URL in Android Chrome. Leave the SSH session
open until sign-in completes. The callback crosses the tunnel and the native
CLI saves credentials to the keyring, without printing them. If the CLI selects a
different callback port, forward that port instead (or free port 4180 and retry).

Leave `DD_CLI_ACCESS_TOKEN` unset: an environment token overrides the keyring
and disables native refresh. Do not use `export-token` for this setup.

The OS service configuration is in
`config/gnome-keyring-daemon.service.d/headless.conf`. The standard user-bus
environment snippet in `config/session-env.zsh` is installed in this VM's
`~/.zshenv`. Neither file contains a token. Credential data and the mode-`0600`
unlock secret remain outside the repository.

For setup/recovery details, see the
[migration record](DD_CLI_UPDATE.md#live-native-renewal-validated--2026-09-06).
Refresh tokens can still expire or be revoked; another login may eventually
be needed. Do not regenerate the keyring unlock secret for an existing keyring.

## Use

Inspect help dynamically because the upstream command surface can change:

```bash
dd-cli --help
dd-cli order --help
dd-cli order status --help
```

Version `0.2.4` retains order tracking and adds promotion information and
address-specific discovery, among other fixes. Follow
`.agents/skills/dd-cli-usage/SKILL.md` for agent-driven use and
`preferences/ordering.md` for persistent ordering preferences.

See `DD_CLI_UPDATE.md` for migration history, validation evidence, and future
update steps.
