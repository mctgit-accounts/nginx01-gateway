# Open work

Running queue for the web gateway infrastructure & security build. Update as
items close.

Last updated: 2026-11-05

## Done

- **Edge host `nginx01-gateway`** built (10.20.30.51 / 192.168.0.51), reboot-safe.
- **nginx front door** — JSON logs, per-IP rate limits, catch-all 444.
- **Wildcard TLS** — Let's Encrypt `*.mankatotech.com` via DreamHost DNS-01,
  auto-renew; staging exercised.
- **Edge hardening** — ufw (SSH LAN-only, 80/443 public-only) + fail2ban
  (external-scoped, 4 jails).
- **DNS** — DreamHost zone published; `app1..app5` → `64.61.212.98`.
- **App tier `webserver01`** built (10.100.200.130/26, single NIC, autostart on) and
  hardened — see `docs/webserver01-BUILD-NOTES.md`. Containment verified:
  `canary -> app:8080` blocked; egress OK.
- **Edge→app hardening** — nginx overwrites client-supplied forwarding headers
  (spoof-proof), hides banners, rejects TRACE/TRACK.
- **App isolation** — per-app Unix accounts + systemd hardening/limits
  (ADR 0008), verified.
- **Config of record** — this repo.
- **First app (`app1`)** — live on the app tier since 2026-11-05: nginx proxies
  it to `webserver01` (`10.100.200.130:8080`, isolated user `app1`) through the
  WatchGuard edge→app rule; the temporary edge copy was retired.
- **WatchGuard edge → app tier** — allow `10.20.30.51` → `10.100.200.130`,
  TCP 8080–8099, added 2026-11-05; verified end-to-end (app1 public HTTPS 200).

## Open

### 1. Wazuh agent on the edge — BLOCKED (asymmetric routing)
The gateway reaches `10.100.200.50:1514` (agent→manager) but not
`10.100.200.100:8443` (the mct-enrollment broker). The WatchGuard 8443 rule
(source `192.168.0.51`) is in place, but the TLS handshake stalls.

**Root cause: asymmetric routing.** The gateway sends the request to
`10.100.200.100` via the WatchGuard, but the broker — on the **multi-homed
automation host** (`10.100.200.100` + `192.168.0.186/.185`) — replies to
`192.168.0.51` directly out its **LAN NIC**. The Firebox never sees the
handshake complete and drops the data. (The Wazuh server itself,
`10.100.200.50`, is single-homed and works fine.)

**Fix options (decide later):**
- **SNAT on the WatchGuard 8443 rule** — broker sees the firewall's internal IP,
  reply is forced back through the Firebox. No host changes.
- **LAN-direct** — broker also binds `192.168.0.186:8443`; gateway uses the
  `mct-automation-host` DNS name (already a cert SAN) via `/etc/hosts`. Internal
  path; lets you close 8443.
- **Edge egress** — allow `10.20.30.51 → 10.100.200.0/24` (8443 + 1514) and
  route `10.100.200.0/24 via 10.20.30.1 dev web0` on the gateway.

**Separate concern:** the enrollment broker (a credential issuer) sits on the
all-important automation host. A dedicated small VM/LXC is the better long-term
home — it also removes the multi-homing asymmetry. (Scoping rationale:
`~/wazuh-siemxdr/docs/enrollment-service-wazuh-scoping.md` §5.5.)

Then: install `wazuh-agent` on the gateway, enroll, add
`deploy/wazuh/localfiles.conf` + the manager decoder/rules.

### 2. App runtime on `webserver01`
Install Node LTS and/or Docker; ship app logs to Wazuh.

### 3. PostgreSQL data tier — planned
ADR 0005. Placement, sizing, backups to decide.

### 4. Remaining apps `app2..app5`
No backends yet. Each follows the same pattern: build on `webserver01`
(`sudo add-appuser appN <port>`), then on the gateway
`sudo add-app appN 10.100.200.130:<port>` — no WatchGuard work needed
(covered by the 8080–8099 rule). Add each app's DNS record at DreamHost.

### 5. WatchGuard (user)
- Reserve `10.20.30.51` + `192.168.0.51` in DHCP (still open).

### 6. Front-door consolidation
`mct-opencode` runs a parallel Caddy front door (`mct-publish`). Decide whether
the nginx gateway supersedes it or they coexist.

### 7. Dedicated edge↔app hop segment — planned (2026-11-05)
Give the nginx↔app link its own point-to-point subnet (e.g. `10.20.40.0/30`) so
app ports are reachable **only** from nginx — removes the shared-subnet
lateral-movement caveat (ADR 0003). Needs a WatchGuard VLAN + host/switch work.

### 8. Not yet addressed
- Gateway HA (single point of failure); backups for gateway config/state.
- Monitoring/alerting for certificate expiry and app health.
- Repo rename to reflect the broader scope (needs repo-admin).
