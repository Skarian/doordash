# DoorDash CLI Linux Port — Update Notes

Last reviewed: 2026-08-02

## Status

- Installed/workspace version: `0.2.1`
- Latest reviewed upstream version: `0.2.1`
- Update state: **migration complete and validated**
- Active Linux binary SHA-256:
  `a6d0e78636a9c5d70a5fa109fef27abdd264b6678163c97b153fd094a172e410`
- Canonical upstream repository:
  <https://github.com/doordash-oss/doordash-cli>
- `0.2.1` release:
  <https://github.com/doordash-oss/doordash-cli/releases/tag/untagged-7e8d1c337378550b3df5>
- Official archive:
  <https://github.com/doordash-oss/doordash-cli/releases/download/untagged-7e8d1c337378550b3df5/dd-cli-v0.2.1-darwin-arm64.tar.gz>
- Published and independently verified archive SHA-256:
  `73bca9c6193500a6e7c18b14e8a569d6df45bbab5966be04262ff7052b771bbb`

The GitHub repository is public. An earlier update review mistakenly queried
`doordash/dd-cli`; the correct repository is `doordash-oss/doordash-cli`.

## How the Existing Linux Port Was Built

This procedure was recovered from the Codex session logs dated 2026-07-24.

1. Download and verify the official macOS Apple Silicon release archive.
2. Extract the release bundle under `vendor/`.
3. Extract the PyInstaller archive into a temporary directory.
4. Copy the official `dd_cli` Python 3.12 bytecode and `dd_cli-*.dist-info`
   metadata into `port/src/`.
5. Install Linux distributions of the open-source runtime dependencies in
   `.venv`.
6. Use `port/launcher.py` to select
   `keyrings.alt.file.PlaintextKeyring` on a headless Linux system.
7. Repackage the unchanged DoorDash application bytecode with a Linux
   CPython/PyInstaller runtime using `port/build.sh`.
8. Install the resulting `dist/dd-cli` at
   `$HOME/.local/bin/dd-cli`.
9. Verify version/help output, OAuth startup, persisted authentication, and a
   read-only authenticated API call.

The current `0.2.1` installed executable and `dist/dd-cli` are identical.
The older `dist/dd-cli-linux-x86_64`, its spec, and its build directory were
archived into the temporary rollback bundle during migration.

## Repository Ownership Boundaries

An expired access token is not evidence that an update deleted the login.
DoorDash currently issues this client a 72-hour access token without a refresh
token, so renewal requires another OAuth authorization. The saved DoorDash
browser session normally makes that authorization automatic.

Updates are separated structurally by ownership:

- `vendor/` contains verified upstream release archives and extracted bundles.
- `port/src/`, `port/build.sh`, and `port/launcher.py` own the upstream-derived
  Linux binary payload and build process. Binary updates may replace these
  intentionally.
- `workflows/auth/` owns provider-neutral browser automation, the interactive
  login flow, the unattended renewal flow, noVNC assets, and user systemd
  templates.
  Upstream extraction and binary rebuilds must not write into this directory.
- `integrations/` contains optional hosting configuration. Integrations may
  configure the generic workflows but must not fork or replace them.
- `port/mobile-login.sh` and `port/mobile-login-status.sh` are compatibility
  delegates only; their canonical implementations live under
  `workflows/auth/`.

Authentication state is runtime-owned and lives outside the workspace:

- `$HOME/.local/share/python_keyring/keyring_pass.cfg` — the CLI's saved
  OAuth access-token record. This headless port uses a plaintext keyring, so
  the file must remain mode `0600`. Never copy it into the workspace, vendor
  archives, build artifacts, logs, or rollback bundles.
- `${XDG_STATE_HOME:-$HOME/.local/state}/dd-cli-linux/chrome-profile` — the
  default durable Chrome profile containing the browser identity session used
  for automatic OAuth approval. Provider configuration may select a different
  existing profile. Preserve it with mode `0700` and never include it in
  artifacts.

After installing a new binary:

1. Do not run a broad cleanup against the user's XDG config, state, or data
   directories; replace only the intended CLI binary and build outputs.
2. Do not change `workflows/auth/` or `integrations/` unless the update
   intentionally changes authentication operations. If user systemd templates
   changed, rerun `bash workflows/auth/install-user-systemd.sh`.
3. Run `systemctl --user start dd-cli-auth-renewal.service` and require a
   successful exit. This confirms that the preserved browser session can renew
   OAuth without user interaction.
4. Confirm `dd-cli-auth-renewal.timer` is enabled and active with a next run
   scheduled approximately 48 hours later.
5. Confirm the test left no Chrome/Xvfb processes and no listeners on ports
   4180, 5900, or 6080. If automatic approval fails, use
   `bash workflows/auth/mobile-login.sh` once; do not delete the credential
   or browser profile as a first troubleshooting step.

## What Changed in 0.2.1

### Packaging and runtime

- The release is still macOS arm64 only, so the Linux payload transplant and
  rebuild remain necessary.
- The application changed from five top-level `dd_cli` modules to a larger
  package containing:
  - `commands/` modules for account, auth, cart, discovery, grocery, order,
    and promo
  - `formatters/` modules for the corresponding domains
  - new `mcp_client.py` and `output.py` modules
- Runtime dependencies remain `click`, `httpx`, `keyring`, and `truststore`.
- New runtime dependency: `tzdata>=2025.2`. The official archive contains
  `tzdata 2026.3`; the current Linux `.venv` has no `tzdata` package.
- The bundled skill is byte-for-byte unchanged from the workspace skill.
- The installer only adds Grok Build as another skill destination; this does
  not affect the Codex installation.
- The access terms now state that logged CLI activity may also be used to
  improve DoorDash products and services.

### Command behavior

- Command names are unchanged.
- Every service command now requires saved credentials. `login` is the only
  command that bypasses the authentication gate; `search` and `menu` are no
  longer public.
- Every service leaf now requires `--intent`. Its value is a two-line
  disclosure containing:

  ```text
  Summary: <who this is for and the goal>
  user prompt/purpose: "<the prompt or instruction that began the workflow>"
  ```

  DoorDash says it may review this value for research and product improvement.
  The help text says not to include sensitive traits, health information,
  credentials, government ID, unnecessary precise location, or information
  about other people.
- `cart add-items` adds:
  - `--group-cart`
  - `--spend-limit-cents`
- `order preview` and `order submit` add:
  - `--priority`
  - `--no-apply-credits`
- Credits now apply by default unless the consumer explicitly opts out. The
  preview and submit flags must match.
- Priority delivery must be available in the preview response, and the same
  flag must be passed to submit so the charged total matches the quote.

The upstream skill still intentionally tells agents to inspect `--help`
dynamically, but its examples do not contain the newly required `--intent`.
The updated Linux install must therefore be verified against leaf help before
using any old command examples.

## Executed Workspace Migration

1. Vendored and checksum-verified the `0.2.1` archive and extracted release
   under `vendor/`; retained the `0.2.0` release for provenance.
2. Freshly extracted the `0.2.1` PyInstaller payload.
3. Replaced `port/src/dd_cli/` and the distribution metadata with the complete
   `0.2.1` payload. A recursive comparison proved every copied payload and
   metadata file is byte-identical to the verified extraction.
4. Matched the release runtime versions in `.venv` and added
   `tzdata==2026.3`. Retained `keyrings.alt==5.0.2` as the Linux-only headless
   keyring adapter.
5. Updated `port/build.sh` to collect the full `dd_cli` package and all
   timezone data. The script now fails if the candidate does not report
   exactly `dd-cli, version 0.2.1`.
6. Updated the pinned version and reproduction details in `port/README.md`.
7. Rebuilt the x86-64 Linux `dist/dd-cli` candidate and validated it before
   promotion.
8. Refreshed `.agents/skills/dd-cli-usage/SKILL.md` from the release bundle;
   its content remains identical to the prior official skill.
9. Atomically installed the validated candidate at
   `$HOME/.local/bin/dd-cli`.
10. Archived the obsolete `dist/dd-cli-linux-x86_64`, its generated spec, and
    its build directory outside the workspace in the rollback bundle.
11. Refreshed OAuth successfully (HTTP 200) and stopped the temporary browser
    service afterward; ports 4180, 5900, and 6080 were confirmed closed.
12. Exercised authenticated, read-only address, cart, payment-method,
    order-history, order-status, and restaurant-search service calls. No cart
    was changed and no order was submitted.

## Validation Checklist

- [x] Archive SHA-256 matches the published checksum.
- [x] Every copied `dd_cli/**/*.pyc` is byte-identical to the extracted official
  payload.
- [x] `dd-cli --version` reports `0.2.1`.
- [x] Root help and all command-group/leaf help render without missing-module
  errors.
- [x] The candidate contains every `dd_cli.commands` and `dd_cli.formatters`
  submodule.
- [x] OAuth credentials were refreshed and persisted in the Linux keyring.
- [x] `DD_CLI_CA_BUNDLE` works with a custom system CA bundle.
- [x] Harmless authenticated reads verify `--json-output` and the required
  `--intent` format.
- [x] Read-only discovery, address, cart, payment-method, order-history, and
  order-status smoke checks.
- [x] No cart mutation, preview mutation, checkout, submit, or order placement
  was performed.
- [x] Group-cart, priority, and credit opt-out flags appear in help.
- [x] `dist/dd-cli` and the installed binary have matching checksums after
  installation.

## Temporary Review Evidence

Temporary extraction/review evidence currently resides under:

- `/tmp/dd-cli-v0.2.1-review.ZmpXY3`
- `/tmp/dd-cli-0.2.1-migration-20260728`

The pre-migration payload, active binary, build files, and archived stale
artifacts are in:

`/tmp/dd-cli-0.2.0-rollback.PtfRDW`

These directories are temporary. The durable releases are under `vendor/`,
and the canonical built binary is `dist/dd-cli`.
