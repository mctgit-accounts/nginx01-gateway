# MCT web gateway — infrastructure & security

Source of truth for the MCT public web gateway: the nginx reverse-proxy front
door, the trust zones it sits in, the app tier that builds/serves custom apps,
the shared application database, and the security controls around all of it.

This repo was originally scoped to the single `nginx01-gateway` host. It now
covers the **whole gateway infrastructure and its security model**.

## Scope

- **Public front door** — nginx TLS termination + name-based routing for
  `appN.mankatotech.com`, wildcard certificate.
- **Trust zones & tiering** — edge/DMZ, app tier, management; default-deny
  between zones.
- **App tier** — `webserver01`, where custom apps are built, tested and served.
- **Data tier** — shared PostgreSQL for application data.
- **Edge security** — ufw, fail2ban, per-IP rate limits, JSON access logs →
  Wazuh.
- **Certificates** — Let's Encrypt wildcard via DreamHost DNS-01.

## Current state

| Component | Address | State |
|---|---|---|
| `nginx01-gateway` (edge/DMZ) | 10.20.30.51 / 192.168.0.51 | **live** — nginx 1.28.3, wildcard TLS, fail2ban, ufw |
| `app1..app5.mankatotech.com` | → 64.61.212.98 | DNS live; **no backends yet** |
| Wazuh agent on the gateway | — | **pending** — enrollment broker unreachable |
| `webserver01` (app tier) | 10.100.200.70 | **planned** — see `docs/webserver01-build-plan.md` |
| PostgreSQL (data tier) | TBD | **planned** |
| Logging platform (`agents`/`manage`) | 10.100.200.50→.60 | separate build (`~/Grafana`) |

## Layout

```
deploy/
  nginx/        log format, map, limits, catch-all, snippets, vhost template
  scripts/      install.sh, add-app.sh, harden.sh
  fail2ban/     jail.local + nginx-gateway-json filter
  acme/         DreamHost DNS-01 hooks, issue.sh, deploy-hook.sh
  wazuh/        agent localfile blocks + manager decoder/rules
docs/
  architecture.md          zones, tiers, topology, data flows
  decisions/               architecture decision records (ADRs)
  webserver01-build-plan.md  app-tier VM plan
  BUILD-NOTES.md           nginx01-gateway host build notes
  OPEN-WORK.md             running open-items queue
```

## Docs

- **[docs/architecture.md](docs/architecture.md)** — the zone/tier model.
- **[docs/decisions/](docs/decisions/)** — why each choice was made.
- **[docs/webserver01-build-plan.md](docs/webserver01-build-plan.md)** — app tier.
- **[docs/OPEN-WORK.md](docs/OPEN-WORK.md)** — what's left.
