# DoorDash CLI Linux payload port

This port runs DoorDash CLI v0.2.1's original Python 3.12 bytecode with a
Linux-native CPython/PyInstaller runtime. The DoorDash application modules in
`src/dd_cli/` are copied unchanged from the checksum-verified official macOS
release. Open-source dependencies are installed as their Linux distributions.

Version 0.2.1 splits the application across `dd_cli.commands`,
`dd_cli.formatters`, `dd_cli.mcp_client`, and `dd_cli.output`, and adds the
`tzdata` runtime dependency. The build collects the complete `dd_cli` package
and bundled timezone data so new command modules are not omitted.

The launcher selects `keyrings.alt.file.PlaintextKeyring` because this
throwaway, headless exe.dev VM has no desktop Secret Service. That backend is
not appropriate for a persistent or shared machine. Set
`PYTHON_KEYRING_BACKEND` to a secure Linux keyring backend to override it.

Build:

```bash
bash port/build.sh
```

Run:

```bash
./dist/dd-cli --help
./dist/dd-cli login
```

DoorDash login uses a localhost browser callback. When logging in from another
computer, forward the callback port to this VM over SSH.

Every 0.2.1 service command requires saved credentials and a leaf-level
`--intent` value. Use the command's current `--help` output for its required
two-line format and privacy guidance.

VM-specific interactive login and automatic token renewal are intentionally
owned by `ops/doordash-auth/`, outside this binary port. See:

```bash
bash ops/doordash-auth/mobile-login.sh
```

`port/mobile-login.sh` remains only as a compatibility delegate. Operational
details and systemd installation instructions live in
`ops/doordash-auth/README.md`.
