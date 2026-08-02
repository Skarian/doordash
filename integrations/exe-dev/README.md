# exe.dev integration

This optional adapter configures the provider-neutral authentication workflows
for an exe.dev VM. The core workflows do not import or depend on this directory.

Install it from the repository root:

```bash
bash integrations/exe-dev/install.sh
```

The installer:

- advertises `https://<vm>.exe.xyz:6080/` for the temporary noVNC session;
- keeps the generic passwordless listener on port 6080;
- preserves the earlier browser profile when one exists;
- installs and enables the generic 48-hour user renewal timer.

exe.dev's documented HTTPS proxy forwards additional ports from 3000 through
9999. Those alternate ports remain private to users who have access to the VM,
so no public-share setting is required for port 6080.

Configuration is written to
`~/.config/dd-cli-linux/auth.conf.d/50-exe-dev.conf`. Add a later fragment, such
as `90-local.conf`, to override the generated values without modifying this
integration.
