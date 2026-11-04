# Architecture — zones, tiers and flows

## Trust zones

| Zone | Subnet | WatchGuard iface | Trust | Contents |
|---|---|---|---|---|
| Office LAN | `192.168.0.0/24` | `192.168.0.1` | **high** (users) | workstations, hypervisor, admin |
| Internal / app tier | `10.100.200.0/24` | `10.100.200.1` | medium | SIEM (`.50`), automation host (`.100`), canary (`.61`), **app tier (`.70`)** |
| Edge / DMZ | `10.20.30.0/24` | `10.20.30.1` | **low** | `nginx01-gateway` (`.51`), `mct-opencode` web0 (`.50`) |
| WireGuard | `10.44.0.0/24` | — | remote | remote-access hub |

Public addresses: `64.61.212.98` (app side — DNAT to the edge) and
`64.61.212.100` (logging platform). Block `64.61.212.0/24`.

## Tiering

```
Internet
   │  80/443
   ▼
WatchGuard (64.61.212.98)  ── DNAT 80/443 ──▶  EDGE: nginx01-gateway 10.20.30.51
                                                    │  (TLS terminates here)
                                                    │  app ports only
                                                    ▼
                                          APP TIER: webserver01 10.100.200.70
                                                    │  db ports only
                                                    ▼
                                          DATA TIER: postgresql  10.100.200.x
```

Management is from the office LAN (hypervisor host / console), never from the
internet.

## Rules of the model

1. **Only the edge is internet-reachable.** DNAT 80/443 targets the gateway and
   nothing else, ever.
2. **Default-deny between zones.** Every cross-zone path is an explicit allow.
3. **TLS terminates at the edge.** Apps speak plain HTTP on the app tier.
4. **Least privilege per hop:** edge→app is app ports only; app→data is db ports
   only; nothing else.
5. **Same-subnet traffic does not traverse the WatchGuard** — inside a zone,
   host firewalls are the only control (this is why the app tier shares the
   internal subnet only deliberately; see ADR 0003).
6. **A new app is one config file** on the gateway plus a backend — DNS and the
   wildcard cert already cover it (`add-app`).

## Data flows

| From | To | Ports | Control |
|---|---|---|---|
| Internet | edge `10.20.30.51` | 80, 443 | WatchGuard DNAT |
| edge | app tier `10.100.200.70` | app ports | WatchGuard allow + host ufw |
| app tier | data tier | 5432 | WatchGuard allow + host ufw |
| app tier | internet (builds) | 443 (+80) | WatchGuard egress allow (or proxy) |
| office LAN | edge / app tier | 22 (admin) | WatchGuard allow + host ufw |
| edge | Wazuh `10.100.200.50` | 1514 | WatchGuard allow (exists) |

## Certificate model

One wildcard certificate `*.mankatotech.com` (Let's Encrypt, DNS-01 via
DreamHost). Covers every `appN` and any future host; the apex stays on DreamHost
shared hosting. Renewed by `certbot.timer`; the deploy hook installs it and
reloads nginx.

## Security posture summary

- Edge: ufw deny-inbound (SSH on the LAN side only, 80/443 on the public side);
  fail2ban external-scoped; per-IP `limit_req`/`limit_conn`; unknown hosts → 444
  logged for fail2ban/Wazuh.
- App tier: no public exposure; app ports open only to the edge; SSH only from
  management.
- Everything relevant ships to Wazuh (nginx access/error, fail2ban, app logs).
