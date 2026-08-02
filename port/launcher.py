"""Linux launcher for the official DoorDash CLI application payload."""

import os


# This throwaway VM has no desktop Secret Service. Use keyring's file backend
# unless the caller explicitly configured a different Linux keyring backend.
os.environ.setdefault(
    "PYTHON_KEYRING_BACKEND",
    "keyrings.alt.file.PlaintextKeyring",
)

from dd_cli.cli import cli


if __name__ == "__main__":
    cli()
