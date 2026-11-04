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
- **Config of record** — this repo.

## Open

### 1. Wazuh agent on the edge — BLOCKED
Enrollment broker `10.100.200.100:8443` is unreachable from the gateway (1514
is open). Need a WatchGuard allow, or a manual key exchange. Then add
`deploy/wazuh/localfiles.conf` and the manager decoder/rules.

### 2. `webserver01` app tier — planned
Build per `docs/webserver01-build-plan.md`. Needs the WatchGuard rules
(edge→app, app→internet egress, mgmt→app SSH).

### 3. PostgreSQL data tier — planned
See ADR 0005. Placement (dedicated host vs the app tier), sizing and backups to
be decided.

### 4. First real app
`app1..app5` currently hit the catch-all. Point one at a backend with
`sudo add-app app1 10.100.200.70:<port>` once `webserver01` exists.

### 5. WatchGuard (user)
- Reserve `10.20.30.51` + `192.168.0.51` in DHCP.
- Confirm `64.61.212.98` is bound for **inbound** DNAT.
- Add the app-tier rules (see build plan).

### 6. Front-door consolidation decision
`mct-opencode` runs a parallel Caddy front door (`mct-publish`, ports
4100–4999). Decide whether the nginx gateway supersedes it or they coexist.

### 7. Not yet addressed
- Gateway HA (single point of failure).
- Backups for gateway config/state.
- Monitoring/alerting for certificate expiry and app health.
