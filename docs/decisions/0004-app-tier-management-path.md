# 0004 — App-tier management via the hypervisor host / console

**Status:** Accepted — 2026-11-04

## Context

The app tier must be manageable without exposing a management interface to the
internet or widening its attack surface. `mct-opencode` is dual-homed (a LAN NIC
for management); the app tier could mirror that or use a single NIC.

## Decision

`webserver01` runs **single-NIC** on the app tier (`10.100.200.70`). It is
managed via the KVM host (`MCT-AUTOMATION-HOST`, `10.100.200.100`, same subnet)
over SSH, with `virsh console webserver01` as the always-available fallback.

## Consequences

- No LAN interface on the app server; one fewer surface.
- Management depends on host↔guest connectivity. If macvtap blocks host↔guest
  reachability, the console is the fallback (verify at build time).
- If LAN-based management is later wanted, add a second NIC (mirror
  `mct-opencode`) — a reversible change.
