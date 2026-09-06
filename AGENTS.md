# Workspace Instructions

## Project boundaries

Use DoorDash's official native Linux release unchanged. Keep only the pinned
installer, minimal credential-store configuration, usage skill, preferences,
and migration notes in this workspace. The token helpers have been retired;
invoke the official executable directly. Never commit credentials, browser
profiles, release archives, extracted bundles, or rebuilt DoorDash binaries.

Treat this VM as headless. Native keyring-based login, live renewal/retry,
and full reboot recovery have passed. Leave `DD_CLI_ACCESS_TOKEN` unset so
the native CLI uses keyring credentials and refreshes them automatically.
Do not recreate token-injecting wrappers, a resident browser, noVNC service,
or automatic browser-login workflow unless the user explicitly asks for that
tradeoff. Reauthorization uses native `login` with a phone/laptop browser and
an SSH callback tunnel; do not use `export-token` for the keyring setup.

## User preferences

For shopping, delivery, grocery, or retail-order tasks, read
`preferences/ordering.md` before searching for or selecting products.

Treat that file as the user's persistent ordering preferences. A preference
applies unless the user explicitly requests something different in the current
conversation.
