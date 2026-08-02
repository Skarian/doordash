# DoorDash CLI on exe.dev

This repository packages the official DoorDash CLI bytecode for Linux and
keeps the exe.dev authentication operations separate from the binary port.

## Layout

- `port/` — Linux binary build inputs and compatibility launchers.
- `ops/doordash-auth/` — interactive OAuth, unattended token renewal, noVNC,
  and systemd definitions owned by this VM integration.
- `vendor/` — checksum-verified upstream releases used by the Linux port.
- `dist/` — validated Linux CLI binary.
- `.agents/skills/dd-cli-usage/` — DoorDash's agent usage instructions.
- `preferences/` — persistent user ordering preferences.

See `DD_CLI_UPDATE.md` before updating the upstream binary. See
`ops/doordash-auth/README.md` for interactive login and the 48-hour renewal
service.

Runtime credentials and browser identity data are deliberately stored outside
the repository under `/home/exedev/.local/share/`.
