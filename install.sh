#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=release.env
source "$repo_dir/release.env"

case "$(uname -s):$(uname -m)" in
    Linux:x86_64) ;;
    *)
        echo "error: this pinned release is for Linux x86-64" >&2
        exit 1
        ;;
esac

for dependency in python3 flock; do
    command -v "$dependency" >/dev/null 2>&1 || {
        echo "error: required command not found: $dependency" >&2
        exit 1
    }
done

install_root="$HOME/.local/lib/dd-cli"
release_dir="$install_root/$DD_CLI_VERSION"
install -d -m 755 "$install_root" "$HOME/.local/bin"
exec 9>"$install_root/.install.lock"
flock 9

# Verify in memory, then extract into the versioned installation. No archive
# or extracted application is kept in the repository or a temporary directory.
python3 - "$DD_CLI_RELEASE_URL" "$DD_CLI_ARCHIVE_SHA256" \
    "$release_dir" "$DD_CLI_ARCHIVE" <<'PY'
import hashlib
import io
from pathlib import Path, PurePosixPath
import sys
import tarfile
import urllib.request

url, digest, destination, archive_name = sys.argv[1:]
root = Path(destination)
with urllib.request.urlopen(url, timeout=60) as response:
    archive = response.read()
if hashlib.sha256(archive).hexdigest() != digest:
    raise SystemExit("error: release archive checksum mismatch")
with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as bundle:
    members = []
    for member in bundle.getmembers():
        parts = PurePosixPath(member.name).parts
        if not parts or parts[0] != archive_name.removesuffix(".tar.gz") or ".." in parts:
            raise SystemExit("error: unexpected archive path")
        if len(parts) == 1:
            continue
        member.name = str(PurePosixPath(*parts[1:]))
        members.append(member)
    if root.exists():
        # An existing version must exactly match the verified release files.
        # Refuse to overwrite a running or locally modified installation.
        for member in members:
            target = root / member.name
            if member.isfile():
                if target.is_symlink() or not target.is_file() or target.read_bytes() != bundle.extractfile(member).read():
                    raise SystemExit(f"error: existing release differs: {target}")
            elif member.issym():
                if not target.is_symlink() or str(target.readlink()) != member.linkname:
                    raise SystemExit(f"error: existing release link differs: {target}")
            elif not member.isdir():
                raise SystemExit("error: unsupported archive member")
    else:
        root.mkdir()
        bundle.extractall(root, members=members, filter="data")
print("Verified official release archive and installation.")
PY

version_output="$("$release_dir/$DD_CLI_EXECUTABLE" --version)"
[[ "$version_output" == *", version $DD_CLI_VERSION" ]]
printf '%s\n' "$version_output"
ln -sfn "$DD_CLI_EXECUTABLE" "$release_dir/dd-cli"

ln -sfn "$release_dir" "$install_root/.current-next"
mv -Tf "$install_root/.current-next" "$install_root/current"
ln -sfn "$install_root/current/dd-cli" "$HOME/.local/bin/dd-cli"

echo "Installed official dd-cli $DD_CLI_VERSION with a direct executable symlink."
