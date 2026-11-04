# 0005 — PostgreSQL as the shared application database

**Status:** Accepted — 2026-11-04

## Context

Custom apps need a SQL database that is free, handles high transaction volume,
and is operationally sane for a small team. The estate currently uses SQLite for
one app (`NCIPCInventory`, documented as a dev deployment with a stated plan to
move to PostgreSQL).

## Decision

Use **PostgreSQL** as the shared application database, one cluster with a
database + role per app, on a **data-tier** host reachable only from the app
tier (and admin).

- License: PostgreSQL License — free, permissive, no per-core fees.
- Single tuned instance handles thousands–tens of thousands of TPS, well beyond
  near-term needs.
- Use a connection pool (PgBouncer) once there are several app instances.
- Backups with `pgBackRest` + a tested restore; replication is not backup.
- HA (streaming replication + Patroni + witness) only when actually needed.

## Alternatives considered

- **MariaDB/MySQL** — also free and fast; Postgres preferred for new apps.
- **SQLite** — fine for single small apps with light writes; single-writer, not
  for concurrent web workloads. Kept for throwaway/one-off apps.
- **CockroachDB / YugabyteDB / TiDB** — distributed scale; too much operational
  complexity until a measured bottleneck exists.
- **SQL Server Express / Oracle XE** — "free" but capped and licensing-tethered.

## Consequences

- `NCIPCInventory` migrates to Postgres when productionized (its docs already
  call for it).
- The data tier is a new tier to build, back up and monitor.
- RAM is the host's constrained resource; size `shared_buffers` accordingly.
