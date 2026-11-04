# 0006 — Edge security controls

**Status:** Accepted — 2026-11-04

## Context

The edge is the only internet-facing host. It must resist scanning, brute force
and floods, and produce telemetry that feeds the estate's Wazuh SIEM.

## Decision

On `nginx01-gateway`:

- **ufw** — deny inbound; SSH only on the LAN side (`chat0`); 80/443 only on the
  public side (`web0`).
- **fail2ban** — external-scoped: all internal networks are in `ignoreip`, so
  bans apply only to internet sources. Jails: `sshd`, `nginx-limit-req`,
  `nginx-gateway-json` (repeated 401/403/444), `recidive`. Ban action `ufw`.
- **nginx** — per-IP `limit_req` (20 r/s, burst 40) and `limit_conn` (50);
  unknown hostnames get `444` and are logged to `blocked.access.log`.
- **Logging** — JSON access logs (structured) plus error logs; shipped to Wazuh
  (agent `localfile`), alongside `/var/log/fail2ban.log` with a custom
  manager-side decoder.

Real client IPs are preserved through the WatchGuard DNAT, so bans are
meaningful.

## Consequences

- Admin/LAN can never be banned (internal `ignoreip`).
- The JSON log format is the single source for fail2ban and Wazuh; changes to it
  must update the fail2ban filter.
- Wazuh ingestion depends on agent enrollment (see `OPEN-WORK.md`).
