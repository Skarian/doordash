#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"

shopt -s nullglob
metadata_files=(port/src/dd_cli-*.dist-info/METADATA)
shopt -u nullglob
if [[ "${#metadata_files[@]}" -ne 1 ]]; then
    echo "error: expected exactly one dd_cli distribution metadata file" >&2
    exit 1
fi

expected_version="$(awk -F ': ' '$1 == "Version" { print $2; exit }' "${metadata_files[0]}")"
if [[ -z "$expected_version" ]]; then
    echo "error: package metadata does not contain a version" >&2
    exit 1
fi

if [[ ! -x .venv/bin/pyinstaller ]]; then
    echo "error: .venv is missing the Linux PyInstaller build environment" >&2
    exit 1
fi

.venv/bin/pyinstaller \
    --clean \
    --noconfirm \
    --onefile \
    --name dd-cli \
    --paths port/src \
    --collect-submodules dd_cli \
    --collect-all tzdata \
    --hidden-import keyrings.alt.file \
    port/launcher.py

file dist/dd-cli
sha256sum dist/dd-cli

version_output="$(dist/dd-cli --version)"
if [[ "$version_output" != "dd-cli, version $expected_version" ]]; then
    echo "error: candidate reported unexpected version: $version_output" >&2
    exit 1
fi
echo "$version_output"
