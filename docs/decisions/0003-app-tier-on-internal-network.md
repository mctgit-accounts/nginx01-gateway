# 0003 — App tier on the existing internal network (10.100.200.0/24)

**Status:** Accepted — 2026-11-04

## Context

The app tier needs an isolated home that only the edge can reach. Options were a
new dedicated VLAN (cleanest, but requires WatchGuard **and** switch/host VLAN
work) or reusing an existing isolated subnet.

## Decision

Place the app tier on the existing internal network **`10.100.200.0/24`**
(`webserver01` at `10.100.200.70`). Add a single WatchGuard allow:
edge `10.20.30.51` → app `10.100.200.70` : app ports.

## Consequences

- No new VLAN/switch configuration; the host already has NICs on this subnet.
- **Accepted caveat:** `10.100.200.0/24` also hosts the SIEM (`.50`) and the
  automation host (`.100`). Same-subnet traffic does **not** traverse the
  WatchGuard, so **host firewalls are the only control** between the app tier and
  those hosts. Mitigations:
  - ufw on `webserver01`: default-deny inbound; app ports only from
    `10.20.30.51`; SSH only from management; default-deny outbound with only
    what builds need.
  - Do not let an app reach `10.100.200.50:1514` (Wazuh) or other internal
    services casually.
- Upgrade path: a dedicated app VLAN if real containment is later required.
