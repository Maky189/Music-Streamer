# Isolation Levels

The SQL standard defines four levels. Each prevents a stricter set of concurrency anomalies, at the cost of more blocking or more retries.

| Level                | Dirty read | Non-repeatable read | Phantom read | Serialization anomaly |
|----------------------|:---------:|:-------------------:|:------------:|:---------------------:|
| READ UNCOMMITTED     | possible* | possible            | possible     | possible              |
| READ COMMITTED (PG default) | no | possible           | possible     | possible              |
| REPEATABLE READ      | no        | no                  | no (in PG)** | possible              |
| SERIALIZABLE         | no        | no                  | no           | no                    |

\* PostgreSQL silently treats READ UNCOMMITTED as READ COMMITTED.
\** The SQL standard allows phantoms here; PG's snapshot isolation prevents them but allows serialization anomalies.

## Setting the level

```sql
-- For one transaction:
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
  -- ...
COMMIT;

-- Or in one go:
BEGIN ISOLATION LEVEL SERIALIZABLE;
```

## What each anomaly looks like

**Dirty read** — Tx A writes, Tx B reads it before A commits, A rolls back. B used data that never existed.

**Non-repeatable read** — Tx A reads `users.subscription`, Tx B updates and commits, Tx A reads again and gets a different value.

**Phantom read** — Tx A runs `SELECT COUNT(*) FROM songs WHERE explicit`, Tx B inserts a new explicit song and commits, Tx A reruns the same query and gets a higher count.

**Serialization anomaly** — Both Tx A and Tx B read the same balance, both decide to deduct, both commit. Each on its own was fine, but together they violated an invariant ("balance ≥ 0").

## Choosing a level

- Start with **READ COMMITTED** (default).
- Bump to **REPEATABLE READ** when a single tx reads the same data multiple times and needs a stable view (reports, multi-step calculations).
- Use **SERIALIZABLE** when correctness depends on concurrency-free reasoning (financial transfers, inventory). Be ready to retry on `serialization_failure` (SQLSTATE `40001`).

## Locking vs MVCC

PostgreSQL uses **MVCC** — readers don't block writers and vice versa. Locks come into play with `SELECT ... FOR UPDATE`, explicit `LOCK TABLE`, or row-level conflicts on writes.

```sql
-- Explicit row lock:
SELECT * FROM playlists WHERE playlist_id = 1 FOR UPDATE;
```

Two sessions doing this for the same row will queue.

## Practice scenarios in this project

- Two sessions adding songs to the same playlist concurrently — show how `song_count` can go wrong without proper locking.
- Two sessions updating the same `users.subscription` — observe lost updates at READ COMMITTED.
- Run a long report at REPEATABLE READ while data is changing — observe stable reads.
