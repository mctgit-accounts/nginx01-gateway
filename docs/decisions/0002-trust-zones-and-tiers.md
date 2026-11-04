# 0002 — Trust zones and a three-tier model

**Status:** Accepted — 2026-11-04

## Context

Internet-facing apps are the most likely workload to be exploited. Where they
sit determines the blast radius of a compromise. The estate has several networks
and a WatchGuard that is default-deny between them.

## Decision

Model the gateway as three tiers in distinct trust zones:

- **Edge / DMZ** (`10.20.30.0/24`, low trust): the nginx front door only.
- **App tier** (internal, medium trust): the web server that builds and serves
  apps.
- **Data tier** (internal, medium trust): the database.
- **Management** (office LAN, high trust): admins.

Rules: only the edge is internet-reachable (DNAT 80/443 → gateway only);
default-deny between zones; TLS terminates at the edge; least privilege per hop.

## Alternatives considered

- **App backends in the edge zone (same L2 as the proxy).** Rejected: no
  containment — a compromised app or proxy reaches every host on that L2.
- **App backends on the office LAN.** Rejected: trust inversion (apps sit next
  to user workstations) and gateway bypass (LAN clients reach app ports
  directly, skipping TLS/logging/rate-limiting/fail2ban).

## Consequences

- A compromise is contained to one tier.
- Cross-zone traffic traverses the WatchGuard and must be explicitly allowed.
- Same-subnet traffic is *not* firewalled — see ADR 0003 for that caveat.
