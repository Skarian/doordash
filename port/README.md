# Build DoorDash CLI for Linux

This directory contains the build inputs for the x86-64 Linux executable. The
current build packages DoorDash CLI `0.2.1`.

## Build

The repository's `.venv` contains the Python 3.12 and PyInstaller build
environment. From the repository root, run:

```bash
bash port/build.sh
```

The build script creates `dist/dd-cli`, prints its file type and SHA-256
checksum, and verifies that it reports the expected version.

## Run

```bash
./dist/dd-cli --version
./dist/dd-cli --help
./dist/dd-cli login
```

`dd-cli login` opens DoorDash's browser sign-in flow with a callback on the
same Linux machine. For a remote server, use the
[mobile login workflow](../workflows/auth/README.md).

## Build contents

The executable combines:

- the original Python 3.12 DoorDash application bytecode and package metadata
  from the checksum-verified official release;
- Linux builds of the open-source runtime dependencies;
- a Linux-native CPython and PyInstaller runtime;
- the complete `dd_cli` package and bundled `tzdata` data; and
- the headless Linux launcher in `launcher.py`.

The DoorDash application payload under `src/dd_cli/` is copied unchanged from
the official release.

## Command requirements

DoorDash CLI `0.2.1` requires saved credentials and a leaf-level `--intent`
value for service commands. Run the leaf command with `--help` for the current
two-line intent format and privacy guidance.

## Credential storage

The headless launcher selects `keyrings.alt.file.PlaintextKeyring`. Keep the
resulting keyring file restricted to the current user with mode `0600` and use
this default on a single-user host. Set `PYTHON_KEYRING_BACKEND` to select a
different installed backend.

## Updating DoorDash CLI

Follow [DD_CLI_UPDATE.md](../DD_CLI_UPDATE.md) when importing a new upstream
release. It records the source archive and checksum, payload boundaries, build
procedure, and validation checklist.
