# Open work

Running queue for the web gateway infrastructure & security build. Update as
items close.

Last updated: 2026-11-04

## Done

- **Edge host `nginx01-gateway`** built (10.20.30.51 / 192.168.0.51), reboot-safe.
- **nginx front door** — JSON logs, per-IP rate limits, catch-all 444.
- **Wildcard TLS** — Let's Encrypt `*.mankatotech.com` via DreamHost DNS-01,
  auto-renew; staging exercised.
- **Edge hardening** — ufw (SSH LAN-only, 80/443 public-only) + fail2ban
  (external-scoped, 4 jails).
- **DNS** — DreamHost zone published; `app1..app5` → `64.61.212.98`.
- **App tier `webserver01`** built (10.100.200.70, single NIC, autostart on) and
  hardened — see `docs/webserver01-BUILD-NOTES.md`. Containment verified:
  `canary -> app:8080` blocked; egress OK.
- **Config of record** — this repo.

## Open

### 1. Wazuh agent on the edge — BLOCKED on one WatchGuard rule
The gateway reaches `10.100.200.50:1514` (agent→manager) but **not**
`10.100.200.100:8443` (the mct-enrollment broker).

Diagnosis: the gateway egresses via its LAN address (`192.168.0.51`, default
route chat0). The automation host's ufw **already allows** 8443 from
`192.168.0.0/24`, so the block is the **WatchGuard** (no rule for this path,
whereas 1514 to `.50` is allowed).

**Change needed (WatchGuard, not the hosts):**
- Allow **`192.168.0.51` → `10.100.200.100`, TCP 8443** (enable logging).
- No host firewall change required.

Then: install `wazuh-agent` on the gateway, enroll, add
`deploy/wazuh/localfiles.conf` + the manager decoder/rules.

Optional: the gateway egressing via the LAN is unusual for a DMZ host. If you'd
rather it use the edge path, add a route on the gateway
(`10.100.200.0/24 via 10.20.30.1 dev web0`) and allow from `10.20.30.51` instead.

### 2. WatchGuard: edge → app tier
`webserver01` is built but the edge cannot reach it yet (verified blocked).
Add: allow **`10.20.30.51` → `10.100.200.70` : app ports** (8080–8099 for now).

### 3. App runtime on `webserver01`
Install Node LTS and/or Docker; ship app logs to Wazuh.

### 4. PostgreSQL data tier — planned
ADR 0005. Placement, sizing, backups to decide.

### 5. First real app
`app1..app5` hit the catch-all. Once rules 2–3 are done:
`sudo add-app app1 10.100.200.70:<port>`.

### 6. WatchGuard (user)
- Reserve `10.20.30.51` + `192.168.0.51` in DHCP.
- Confirm `64.61.212.98` is bound for **inbound** DNAT.
- Add rules 1 and 2 above.

### 7. Front-door consolidation
`mct-opencode` runs a parallel Caddy front door (`mct-publish`). Decide whether
the nginx gateway supersedes it or they coexist.

### 8. Not yet addressed
- Gateway HA (single point of failure); backups for gateway config/state.
- Monitoring/alerting for certificate expiry and app health.
- Repo rename to reflect the broader scope (needs repo-admin).
