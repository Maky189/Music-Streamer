# ACID Properties

ACID is the contract a relational database makes with you about how transactions behave.

| Letter | Property | One-line meaning |
|--------|----------|------------------|
| **A** | Atomicity   | A transaction is all-or-nothing. |
| **C** | Consistency | A committed transaction leaves the DB in a valid state (constraints hold). |
| **I** | Isolation   | Concurrent transactions don't see each other's half-finished work. |
| **D** | Durability  | Once committed, the change survives crashes. |

## Atomicity

If any statement in a transaction fails (or you `ROLLBACK`), every change in that transaction is undone. There's no "we got halfway."

> **Why it matters in this project:** Adding a song to a playlist is two writes — `playlist_songs` insert and `playlists.song_count` update. If the second fails, the first must vanish.

## Consistency

The database refuses transitions that violate constraints (PK, FK, CHECK, NOT NULL, triggers, unique indexes). The DB is consistent before and after the transaction; it may be temporarily inconsistent *during* it.

> Example: `playlists.song_count >= 0`. A bug that decrements an empty playlist's count gets rejected on `COMMIT`.

## Isolation

Two transactions running at the same time should produce a result equivalent to *some* serial ordering of them. SQL standard defines four isolation levels — see `03-isolation-levels.md`.

Phenomena to know:
- **Dirty read** — read uncommitted data from another tx.
- **Non-repeatable read** — same row read twice returns different values.
- **Phantom read** — same range query returns different row sets.
- **Serialization anomaly** — concurrent serializable txs produce a result no serial order would.

## Durability

After `COMMIT` returns success, the change survives `kill -9`, power loss, OS crash. PostgreSQL achieves this via the **WAL** (write-ahead log): changes are flushed to the WAL on disk before commit acknowledgement.

> You can simulate "crash" durability tests by `pg_ctl stop -m immediate` and restarting — committed work must still be there.

## Practical takeaways

- Wrap multi-step business operations in a transaction. **Always.**
- Don't fight the constraints — let them enforce consistency for you.
- Pick the *weakest* isolation level that's still correct; stronger levels cost concurrency.
- Trust commit. Don't add app-level "did it really save?" loops.
