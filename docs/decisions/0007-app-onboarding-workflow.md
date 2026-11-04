# 0007 — App onboarding workflow (`add-app`)

**Status:** Accepted — 2026-11-04

## Context

The goal is to build apps and put them into production without rebuilding
infrastructure per app.

## Decision

Onboarding an app is:

1. Run the app on the app tier on a port.
2. `sudo add-app <app> <host:port>` on the gateway (renders a vhost from
   `/etc/nginx/templates/app.vhost.template`, validates, reloads nginx).
3. Point DNS if needed — but the wildcard `*.mankatotech.com` already covers
   `appN`, so normally nothing is needed.

The template includes proxy headers (`X-Forwarded-For`/`Host`/`Proto`),
WebSocket upgrade support, `client_max_body_size`, and per-IP rate limits, and
writes a per-app JSON access log (`/var/log/nginx/<app>.access.log`).

## Consequences

- A new app is one file + a reload — no DNS, cert, or firewall work.
- Backends must be reachable from the edge on the app ports (see ADR 0003).
- The template is the contract: new shared behaviour goes there, not in
  per-app files.
