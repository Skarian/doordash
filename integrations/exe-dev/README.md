# DoorDash login on exe.dev

This integration makes the remote DoorDash login page available through an
exe.dev VM's authenticated HTTPS proxy and enables automatic authorization
renewal.

## Install

From the repository root, run:

```bash
bash integrations/exe-dev/install.sh
```

The installer:

- writes the VM-specific login URL and listener settings;
- reuses an existing DoorDash Chrome profile when present;
- installs and starts the 48-hour user renewal timer; and
- reports when systemd user lingering needs to be enabled.

## Sign in

Start an interactive login:

```bash
bash workflows/auth/mobile-login.sh
```

Open the printed `https://<vm>.exe.xyz:6080/` URL and complete the DoorDash
login. exe.dev forwards ports 3000 through 9999 over HTTPS, so port 6080 is
available to users who have access to the VM. See the
[exe.dev proxy documentation](https://exe.dev/docs/proxy).

Check the temporary login service with:

```bash
bash workflows/auth/mobile-login-status.sh
```

## Configuration

The installer writes:

```text
~/.config/dd-cli-linux/auth.conf.d/50-exe-dev.conf
```

That file configures the listener on port 6080 and advertises this URL:

```text
https://<vm>.exe.xyz:6080/vnc.html?autoconnect=1&resize=scale
```

Place local overrides in a later fragment such as
`~/.config/dd-cli-linux/auth.conf.d/90-local.conf`. The authentication workflow
loads fragments in lexical order.

Set `EXE_DEV_VM_NAME` or `DD_MOBILE_PORT` before running the installer to
override the detected VM name or default port.

## Keep renewal running after logout

The installer enables `dd-cli-auth-renewal.timer`. Enable lingering once if the
installer reports that it is disabled:

```bash
sudo loginctl enable-linger "$USER"
```

Verify the schedule with:

```bash
systemctl --user list-timers dd-cli-auth-renewal.timer --all
```
