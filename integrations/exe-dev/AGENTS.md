# exe.dev integration instructions

Use only documented exe.dev behavior when changing this integration. The HTTPS
proxy documentation is at <https://exe.dev/docs/proxy.md>.

Keep provider-specific hostnames, proxy URLs, and installation behavior inside
this directory. The workflows under `workflows/auth/` must remain usable on a
normal Linux host without importing exe.dev configuration.
