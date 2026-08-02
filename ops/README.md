# VM operations

This directory contains local runtime integrations for the exe.dev VM. It is
separate from vendored or upstream-derived application payloads so package and
binary updates can replace their own files without overwriting local services.

- `doordash-auth/` owns DoorDash OAuth browser automation and its systemd
  renewal schedule.
