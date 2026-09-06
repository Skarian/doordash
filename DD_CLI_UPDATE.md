# DoorDash CLI update record

Last reviewed: 2026-09-06

**Latest status: migration complete.** Native keyring login, real automatic
refresh with rotated credentials, authenticated reads, and full VM reboot
recovery have passed. `dd-cli` invokes the official binary directly. The
unused token helpers and expired token file have been removed. Earlier
sections below document the history; see the reboot/retirement section for
the runtime result and the housekeeping section for the subsequent host cleanup.

## Current state

- Upstream: <https://github.com/doordash-oss/doordash-cli>
- Installed release: `v0.2.4` (latest official release when checked)
- Release page: <https://github.com/doordash-oss/doordash-cli/releases/tag/v0.2.4>
- Platform: official `linux-amd64` bundle
- Archive SHA-256:
  `37eec0c72bcb663aaf9759ea098d49d9c02266bb895cbbfbadeae41866608dd4`
- Official ELF SHA-256:
  `12e5e3fe986072c80ec694c6881fd340a33939e854168e9700bddc64ae10328a`
- Distribution model: local install only; this repository no longer builds or
  publishes a Linux port

DoorDash now publishes its own native Linux build. The former workspace copied
Python bytecode out of the macOS release, rebuilt it with a Linux runtime, and
maintained a browser/noVNC/systemd authentication workflow. Those components
became unnecessary and have been removed.

## Relevant release changes

- v0.2.3 introduced native Linux x86-64, address lookup/addition, post-submit
  order tracking, group-inclusive history, and credential refresh improvements.
- v0.2.4 adds promotion information in menus/items, `--address-id` for search
  and nearby discovery, fixes large-menu responses and discounted cart prices,
  and updates the bundled agent onboarding instructions.

## Authentication findings

**Correction to earlier advice:** "refresh does not extend to headless Linux"
was too broad. The distinction is the credential path, not simply the OS.
The official Linux executable contains the same generic-keyring refresh logic
as the previous release. Its environment-token path deliberately bypasses it.

The public upstream repository's current tree contains a README, not the
application's original source. For this review, the official PyInstaller
bundle's Python 3.11 code objects were inspected and disassembled in memory.
The installed executable and bundle were not patched or rebuilt.

### What the official binary actually does

| Path | Stored credentials | Renewal behavior |
| --- | --- | --- |
| `export-token` → file → launcher environment | Access token only | No refresh callback; replace after expiration |
| `login` → generic OS keyring | Access token, expiry, and refresh token if issued | Refresh callback enabled; retries an eligible failed request once |
| Former browser automation | Browser session/cookies plus exported token | Repeated browser authorization, not the CLI's refresh-token grant |

Relevant original code locations (module/function and embedded source line):

- `dd_cli.cli._resolve_access_token`, line 25: an environment token wins over
  keyring credentials and is marked as environment-sourced.
- `dd_cli.cli.cli`, lines 145–155: sets `refresh_token_callback=None` for an
  environment token; enables the callback for keyring credentials.
- `dd_cli.oauth._keyring_get_blob` / `_keyring_set_blob`, lines 153/161:
  generic `keyring.get_password` / `set_password`, without a macOS-only gate.
- `dd_cli.oauth.persist_tokens`, line 204: stores the token response, expiry,
  and refresh token; retains an existing refresh token if a later response
  omits its replacement.
- `dd_cli.oauth.refresh_persisted_access_token`, line 477: loads the saved
  refresh token, performs the OAuth refresh grant, and persists the result.
- `dd_cli.mcp_client.MCPClient._post`, line 282: on an eligible 401/403,
  attempts refresh once, updates the access token, and retries the request.
  Device-verification gating is excluded. This is on-demand renewal, not a timer.
- `dd_cli.commands.auth.export_token`, line 73: uses the login exchange with
  `persist=False` and prints only the access token. It does not retain the
  refresh token, even if the server issued one.

The extracted modules below were byte-for-byte identical between v0.2.3 and
v0.2.4 (SHA-256 of the raw embedded module data):

```text
dd_cli.oauth         0d01ff29a71d333ef14666c4a0686f1b3e527fb3208c4801599acc822250744b
dd_cli.cli           170319e2093b0a91ae2a18c4d8832fac578dadf27daa7c70c5fd6370031b1b78
dd_cli.commands.auth 4fae505dc61dc44e9ab3f657d9c12b60e538f55ac089fd0ac8a6c0fe019d44f3
```

### What this means for this VM

The VM can stay headless. Browser approval and token storage are separate
concerns. A phone/laptop browser can complete the localhost OAuth callback
through SSH; neither VNC nor a browser installed on the VM is required.

The current launcher loads the token file into `DD_CLI_ACCESS_TOKEN`, so it
selects the non-refreshing path. A systemd timer cannot extend that token's
expiry or recover the refresh token discarded by `export-token`. Repeated API
calls do not constitute renewal. No "keep alive forever" guarantee is justified.

For unattended renewal, the next candidate is the native keyring path with
Linux Secret Service, not the old browser stack. Python keyring documents
headless Linux operation using D-Bus and an unlocked GNOME keyring, without
X11. This still introduces a daemon/session and an unlock-secret decision,
especially across reboot. This VM does not currently have the needed keyring
daemon configured. Earlier session history also records the lack of a login
password/TPM solution for automatic unlock.

The release bundles Linux keyring backends and contains the refresh logic,
but this does **not** prove end-to-end server issuance, backend availability,
refresh acceptance, or unattended reboot behavior. Upstream issue #88 asks
for this Linux setup and remained open without a documented resolution when
checked. Treat it as a candidate requiring a live test, not an upstream
promise of supported unattended Linux refresh.

### Recommendation and remaining test

1. Keep the official native bundle and minimal local integration. Keep the
   legacy VNC/browser/build/renewal workflows retired.
2. For the smallest maintenance footprint, use `dd-cli-store-token --login`
   through the Termux tunnel whenever the access token expires. This captures
   the token directly; no chat copy/paste or resident service is involved.
3. If unattended renewal is required, configure a narrowly scoped headless
   keyring, choose how it unlocks after reboot, and perform a fresh native
   `login` through the same tunnel. Do not export a token for this test. Run
   the native executable without `DD_CLI_ACCESS_TOKEN` and without the local
   token-injecting launcher so keyring credentials can be selected.
4. Verify credential storage without printing secrets, authenticated reads,
   a real expiry/refresh/retry cycle, and reboot/unlock. Only after these pass
   should keyring mode replace the file-token default. The current access
   token cannot supply the missing refresh token.
5. Let the native on-demand callback handle refresh if validated. Add a
   timer only for a demonstrated operational need, not on speculation.

No keyring service or browser automation was installed during this review.

Sources: [upstream README](https://github.com/doordash-oss/doordash-cli),
[v0.2.4 release](https://github.com/doordash-oss/doordash-cli/releases/tag/v0.2.4),
[Linux keyring issue #88](https://github.com/doordash-oss/doordash-cli/issues/88),
[keyring headless Linux documentation](https://keyring.readthedocs.io/en/latest/#using-keyring-on-headless-linux-systems).

## Local design

- `release.env` pins the upstream URL, version, executable, and archive digest.
- `install.sh` verifies and installs the complete official bundle in a
  versioned directory, then advances `~/.local/lib/dd-cli/current`.
- `bin/dd-cli` injects the secure token file only when the environment variable
  is absent, then executes the official binary unchanged.
- `bin/dd-cli-store-token` prompts without echo, or directly captures native
  `export-token` with `--login`, and atomically writes a mode `0600` token file.
  A failed export leaves the existing token untouched.
- The official DoorDash usage skill and the user's ordering preferences remain
  local to this workspace.

The previous official `0.2.3` bundle remains outside the repository for rollback.
The pre-migration `v0.2.1` binary is retained at
`~/.local/lib/dd-cli/legacy-0.2.1/dd-cli`, and git tag `v0.2.1` preserves the
old repository state if forensic rollback is ever needed.

## Prior migration and live validation — 2026-08-22

- Verified the official archive against the pinned SHA-256 digest.
- Confirmed the native executable runs on this VM and reports `0.2.3`.
- Confirmed root, address, order, and leaf help render from the native bundle.
- Installed the versioned bundle and token-aware launcher; preserved the
  `v0.2.1` executable separately for rollback.
- Removed the custom build, vendored macOS releases, packaged binary, hosted
  integration, and GitHub release workflow from the working tree. These remain
  recoverable from git tag `v0.2.1`.
- Exported a token using Android Chrome with an SSH localhost callback tunnel
  from Termux, then stored it in the local mode-`0600` token file.
- Exercised authenticated read-only address, active-cart, card,
  group-inclusive order-history, order-status, and restaurant-search calls.
- Confirmed `DD_CLI_CA_BUNDLE` with an authenticated request.
- Disabled and removed the obsolete authorization timer and service.
- Removed the legacy browser/noVNC workflow, provider configuration, browser
  profile, runtime state, and migration logs.
- Confirmed the related browser processes and listeners were stopped.

No cart mutation, preview/submit checkout, or order placement has been performed.

## Review and upgrade validation — 2026-09-06

- Reviewed this thread and related workspace session records, including the
  original Linux port, keyring discussion, Termux callback success, and removal
  of browser-based renewal. Credentials were not copied into this record.
- Checked official GitHub releases and the public upstream tree; verified
  v0.2.4 archive digest, installed the unmodified complete Linux bundle, and
  advanced the `current` symlink. Reinstall verification compared release
  file contents against a fresh checksum-verified archive.
- Confirmed `dd-cli --version` reports `0.2.4`, help renders, and discovery
  exposes the new address option. Synced the usage skill to the official bundle.
- Inspected embedded OAuth, CLI, auth-command, and MCP-client implementation.
- Synthetic tests of original code objects passed: generic-keyring refresh
  storage, refresh-token retention on access-token replacement, and callback
  selection for environment versus keyring credentials. These used fake
  credentials/endpoints, not a live refresh grant.
- Token-helper synthetic tests passed: direct capture, VM browser suppression,
  no token in stdout, mode `0600`, and preservation of the old token on failed,
  empty, or invalid export. Synthetic test data was removed afterward.
- Shell syntax and diff whitespace checks passed.
- Confirmed no resident Chrome/Chromium, Xvfb, VNC, websockify, or keyring
  daemon; no remaining `dd-cli` user-unit files; and no listeners on the
  OAuth callback or former VNC ports. This shell has no user D-Bus connection,
  so a live `systemctl --user` query was unavailable.
- The saved real access token expired on 2026-08-25 at 07:45:39 UTC. A v0.2.4
  read-only `address list` attempt failed with the expected authentication
  error. It did not validate an authenticated v0.2.4 API response. The saved
  credential was not changed. Fresh sign-in remains necessary for live tests.

The workspace now retains ten project files (excluding `.git`): instructions,
README, migration record, release pin, installer, two launch/token helpers,
usage skill, preferences, and ignore rules. The old code remains in git
history; keeping a local repository is useful for the pin and preferences,
but hosting or publishing a fork is no longer necessary. No commit or push
was performed, and unrelated preference edits were preserved.

## Native-keyring pilot — 2026-09-06

The user approved native credential storage, live validation, and eventual
removal of the token helpers. This section supersedes the earlier statement
that no keyring daemon is installed; that was true before the pilot.

### Installed and configured

- Installed Ubuntu's `gnome-keyring` and `libsecret-tools` with
  `--no-install-recommends` (18 new packages and one dependency upgrade;
  approximately 28.4 MB additional installed size). Stale package indexes
  initially caused download failures; refreshing indexes resolved them.
- Used the existing persistent user session (UID 1000, lingering already
  enabled) and its D-Bus at `/run/user/1000/bus`. No new desktop, VNC, browser,
  or authentication-renewal timer was introduced.
- Enabled the standard `gnome-keyring-daemon.service` at the user default
  target. The repository drop-in
  `config/gnome-keyring-daemon.service.d/headless.conf` selects only the
  `secrets` component and supplies the unlock secret through standard input.
- Generated a random unlock secret at
  `~/.local/state/dd-cli-keyring/unlock-secret` (directory `0700`, file `0600`).
  The keyring is encrypted on disk, but this same-VM unlock secret means this
  design does not protect against compromise of the user account/VM. It
  provides unattended startup without a desktop password prompt.
- Credential data lives under `~/.local/share/keyrings/`, outside this repo.
  Do not overwrite or regenerate the unlock secret for an existing keyring.
- Masked the newly installed, unrelated `gcr-ssh-agent.service` and socket
  for this user; they are not needed for DoorDash authentication.
- Left the official binary, old access-token file, and token wrappers intact.

### Checks completed

- Stored and retrieved a synthetic secret through Secret Service without X11.
- Restarted the keyring daemon; the secret persisted and was automatically
  unlocked without an interactive prompt.
- Removed the synthetic test item after the check.
- Invoked the official native CLI directly with the access-token environment
  override removed and the user D-Bus set. The CLI passed its keyring lookup
  and reported missing credentials, not an unavailable keychain.
- A daemon restart is **not** a full VM reboot test. DoorDash login, live
  requests, real refresh, native expiry/retry, and reboot validation remain.

### Next: phone-assisted native login

Connect from Termux, keeping the SSH session open:

```bash
ssh -o ExitOnForwardFailure=yes -L 4180:127.0.0.1:4180 doordash.exe.xyz
```

The agent can then start the native login and supply its URL, or run this
inside that SSH session (these paths are specific to this VM):

```bash
env -u DD_CLI_ACCESS_TOKEN \
  XDG_RUNTIME_DIR=/run/user/1000 \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
  BROWSER=true \
  /home/exedev/.local/lib/dd-cli/current/dd-cli login
```

Open the printed authorization URL in the phone browser. This is the native
`login`, not the repo's `dd-cli-store-token --login` and not `export-token`.
Do not enable verbose authentication output. Check token presence/expiry
without printing credential values, then perform read-only checks.

For non-interactive commands, explicitly supply the user D-Bus environment
until normal shell/session environment propagation is validated. Do not add
another token wrapper as a workaround.

### Reproducing the service configuration

Install the two packages above, then create a mode-`0700` directory at
`~/.local/state/dd-cli-keyring/`. Only for a new setup with no existing keyring
or unlock secret, generate the secret using `openssl rand -hex -out
~/.local/state/dd-cli-keyring/unlock-secret 48` under `umask 077`.
Install the tracked drop-in at
`~/.config/systemd/user/gnome-keyring-daemon.service.d/headless.conf`, run
`systemctl --user daemon-reload`, and enable/start
`gnome-keyring-daemon.service`. Ensure the user's session persists at boot.
Never commit the generated secret or keyring files.

### Retirement gate

After authenticated reads, real refresh/expiry-retry, and restart validation
pass, remove the two token helpers and obsolete access-token file/overrides,
change installation to expose the native executable directly, and update
the instructions. Keep installer/pin, usage skill, preferences, notes, and
the minimal credential-store configuration. No retirement was performed
during this pilot setup, and no order/cart changes were made.

## Live native renewal validated — 2026-09-06

- Phone/Termux-assisted native `login` completed successfully. The native
  executable confirmed storage in SecretService under service
  `DoorDash CLI credentials`, account `doordash-cli-user`.
- Verified presence of both access and refresh tokens without displaying
  their values. A separate native process completed an authenticated
  read-only `address list` request.
- Tested the actual expiry/retry path immediately: verified that the old
  access-token file belonged to the same account and had expired, then
  temporarily substituted that expired access token in the keyring while
  preserving the newly obtained refresh token. The prior valid credential
  was retained only in process memory for recovery if needed.
- The unchanged native CLI then completed `address list` successfully,
  persisted a newly issued access token, and **rotated the refresh token**.
  This was a real DoorDash refresh grant and successful native retry, not
  synthetic credentials or a mocked endpoint. The refreshed credentials
  were retained; no rollback to the superseded refresh token was performed.
- Restarted the keyring daemon with real credentials present. Automatic
  unlock and an authenticated native request both passed afterward.
- Found that ordinary agent shells lacked a user D-Bus environment even
  though the session bus was running. Added the standard conditional
  `DBUS_SESSION_BUS_ADDRESS` export in `config/session-env.zsh` and the
  previously absent `~/.zshenv`. Explicitly supplied bus addresses are
  preserved. New ordinary shells now find Secret Service without a wrapper.
- Replaced `~/.local/bin/dd-cli` with a symlink to the official native
  executable. The replaced launcher was verified identical to the retained
  `bin/dd-cli` before switching, so its source remains available for rollback.
  Updated `install.sh` to install this direct symlink, not either token helper.
- Plain `dd-cli address list` passed with no special environment prefix and
  no access-token override. All response personal data was withheld from logs.
- The old access-token file, repository helper sources, and installed token
  capture helper are temporarily retained but are **not used** by normal
  `dd-cli`. Delete them after the full reboot gate passes.

No order/cart changes, commits, or pushes were made. No browser or renewal
automation was added. The one remaining runtime validation is a full VM
reboot, which will disconnect the user's SSH tunnel. Service restart tests
must not be represented as a completed full reboot test.

To reproduce shell integration on this zsh-based VM, merge
`config/session-env.zsh` into `~/.zshenv`; do not overwrite an existing shell
configuration. Other shells/services must inherit the same standard user-bus
environment. The account's existing systemd user environment already has it.

## Full reboot and retirement completed — 2026-09-06

- The user approved a full VM reboot. Boot ID changed from
  `75323a30-5117-40be-a98b-17607a851632` to
  `af3b6e9d-3a21-456e-b84d-543c00723b7e`; the new boot began at
  `2026-09-06 23:24:33 UTC`.
- The standard keyring service started automatically, both saved tokens were
  available, and a plain `dd-cli address list` succeeded without an environment
  token, a special command prefix, another phone login, or any service-start
  intervention. Personal response data was not printed.
- Removed `bin/dd-cli` and `bin/dd-cli-store-token` from the repository, the
  installed `~/.local/bin/dd-cli-store-token`, and the confirmed-expired
  `~/.local/state/dd-cli/access-token`. Removed its empty state directory.
  These retired helper files and expired token were not separately backed up.
  The live keyring credentials and unlock secret were preserved unchanged.
- `~/.local/bin/dd-cli` remains a direct symlink to the complete, unmodified
  official bundle. No custom login or renewal code is in the runtime path.
- The remaining configuration consists of the standard credential-store
  service drop-in and a standard per-user D-Bus environment snippet. There is
  no VNC/browser stack, token-injecting wrapper, or renewal timer.
- Re-ran `./install.sh`: the archive and installed bundle verified, the direct
  executable symlink remained correct, and neither helper was recreated.
  A final plain native authenticated read passed. Shell syntax and diff
  whitespace checks passed; the workspace contains ten project files.

No orders or cart changes were made. The old versioned native bundle remains
outside the repository for binary rollback; credentials are not archived in
the repository. No commit or push was performed, and unrelated preference
changes were preserved.

## Final host housekeeping — 2026-09-06

The user authorized housekeeping followed by committing and pushing the
migration to the existing repository's `main` branch.

- Purged nine unused packages: `google-chrome-stable`, `novnc`,
  `python3-novnc`, `websockify`, `python3-websockify`, `x11vnc`, `xvfb`,
  `libvncclient1`, and `libvncserver1`. The package manager reported 440 MB
  freed. No broad `autoremove` was run: shared libraries and Python tools
  potentially used by other applications were preserved.
- Removed the inactive `~/.local/lib/dd-cli/0.2.3` and
  `~/.local/lib/dd-cli/legacy-0.2.1` directories (approximately 50 MiB total).
  `current` still resolves to the official `0.2.4` bundle.
- The official v0.2.3 archive can be downloaded again if needed. Before
  deletion, the custom v0.2.1 binary was verified byte-identical to
  `dist/dd-cli` in git tag `v0.2.1`, so that copy remains recoverable from
  history. Installed packages can likewise be reinstalled.
- Found and removed the obsolete
  `~/.local/share/python_keyring/keyring_pass.cfg` and its empty directory.
  It contained only the legacy `dd-cli` entry, not other applications' data.
  This obsolete credential file was not backed up. The active Secret Service
  credentials and unlock secret were untouched.
- Added ignore rules for credential files and downloaded release archives.
- The existing unrelated edits to `preferences/ordering.md` were preserved
  locally and excluded from the migration commit. Git history was not rewritten.
- Post-cleanup checks passed: plain native authenticated access, active keyring
  service, the correct official binary symlink, and absence of all nine retired
  packages. Shell syntax and diff whitespace checks passed. The staged tree was
  checked against the live access token, refresh token, and unlock secret, plus
  common credential patterns; no credentials or application binaries were found.

## Updating later

### Reboot validation checkpoint

The user approved a full VM reboot for the final validation. Pre-reboot boot
ID: `75323a30-5117-40be-a98b-17607a851632`. Native renewal and read-only access
have already passed; the keyring service is enabled at the user default target.
This checkpoint is resolved: different boot ID, automatic service startup,
and plain native authenticated reads were verified before retiring the helpers.

### Release update procedure

1. Review the latest official release notes and bundled usage skill.
2. Update all values in `release.env` from the official Linux asset.
3. Run `./install.sh`; the prior versioned install remains available for
   rollback.
4. Run `dd-cli --version` and inspect root/group/leaf help dynamically.
5. Run authenticated read-only smoke checks using native keyring credentials.
   Use native `login` if reauthorization is required. Never use `order submit`
   as a test.
6. Update this record with command/schema changes and the validation date.
