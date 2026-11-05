# 0008 — App isolation via per-app Unix accounts

**Status:** Accepted — 2026-11-04

## Context

`webserver01` hosts many custom apps. By default they share one user, one
filesystem view, and one CPU/memory pool — so one compromised or runaway app
affects all of them.

## Decision

Isolate apps with **per-app Linux user accounts** (not containers, for now —
chosen as the lighter option):

- `add-appuser <app> [port]` creates a system user/group `<app>` (no login, no
  sudo) and `/srv/apps/<app>` (mode 0700, owned by `<app>`).
- A systemd template `webapp@.service` runs `/srv/apps/<app>/run.sh` as
  `User=%i`, with:
  - hardening: `ProtectSystem=strict`, `ProtectHome`, `PrivateTmp`,
    `PrivateDevices`, `NoNewPrivileges`, `ProtectKernel*`,
    `RestrictAddressFamilies`, `RestrictNamespaces`, `LockPersonality`;
  - cgroup limits: `CPUQuota=100%`, `MemoryMax=512M`, `TasksMax=256`.

`MemoryDenyWriteExecute` is deliberately **not** set — it breaks Node/V8 JIT.

## Consequences

- An app can only read/write its own directory and a private `/tmp`; it cannot
  read another app's files (verified: `beta` → *Permission denied* on `alpha`'s
  files).
- One app cannot starve the others (CPU/memory caps).
- **Limitations vs containers:** apps share the network namespace, so they can
  reach each other's ports on localhost, and egress policy is host-wide rather
  than per-app. Containers (or a per-app `IPAddressAllow`) are the upgrade path
  if that matters.
- Resource caps are defaults; an app can override via a drop-in.
