# 0001 — Single nginx reverse-proxy front door with a wildcard certificate

**Status:** Accepted — 2026-11-04

## Context

Multiple apps (`app1..appN.mankatotech.com`) must be served from a single public
IP, without building TLS/DNS infrastructure per app. The estate already runs a
Caddy front door on `mct-opencode` for the tech-publishing flow.

## Decision

Use one nginx reverse proxy (`nginx01-gateway`) on the edge zone as the public
front door. It terminates TLS and routes by hostname (SNI / `Host`) to backends
by name. Certificates are a **single wildcard** `*.mankatotech.com` issued from
Let's Encrypt via the DreamHost DNS-01 API.

The wildcard is issued **without the apex**: the auth hook removes "stale" TXT
values for the same name, so a cert needing two simultaneous values at
`_acme-challenge.mankatotech.com` (apex + wildcard) would break. The apex stays
on DreamHost shared hosting.

## Consequences

- Adding an app = one vhost file (`add-app`) — no DNS or certificate work.
- One place for TLS, logging, rate limiting and fail2ban.
- The gateway becomes a single point of failure; HA is future work.
- The `mct-opencode` Caddy front door remains a parallel/second door; a
  consolidation decision is open (see `OPEN-WORK.md`).
