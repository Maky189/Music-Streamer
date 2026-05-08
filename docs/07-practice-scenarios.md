# Practice Scenarios

Realistic situations to practice the techniques in this project. The `practice/` folder contains stub `.sql` files for each — fill them in.

## 1. Add song to playlist (atomic)

Inserting into `playlist_songs` and bumping `playlists.song_count` must succeed together. Use a **transaction** plus a **stored procedure** so the application only calls one routine.

## 2. Transfer playlist between users

Two writes — update `playlists.user_id`, log the change to `audit_log`. Wrap in a transaction. Verify foreign keys still resolve.

## 3. Bulk-import an artist's discography

Insert an artist, several albums, and dozens of songs. If any row fails (duplicate, bad year), the whole import rolls back. Use **savepoints** to allow per-album partial recovery if you want a softer mode.

## 4. Concurrent playlist edits

Two sessions add songs to the same playlist at the same time. Without locking, `song_count` can become wrong. Demonstrate the bug at READ COMMITTED, then fix with `SELECT ... FOR UPDATE` on the parent row.

## 5. Maintain `song_count` via trigger (alternative to (1))

Instead of trusting every caller to bump the count, attach AFTER INSERT/DELETE triggers to `playlist_songs`. Compare ergonomics with the procedural approach.

## 6. Soft-delete inactive users

A maintenance procedure that uses a **cursor** to walk users with no plays in the last 12 months, downgrading them to `'free'` and closing their sessions.

## 7. Audit every write to `songs`

Trigger writes the OLD/NEW snapshot to `audit_log` as JSONB. Practice querying the log: "what changed in the last hour?"

## 8. Validate song duration

A `BEFORE INSERT` trigger that rejects songs longer than 1 hour even when bypassing the CHECK (e.g., via `ALTER TABLE`).

## 9. Deadlock — cause and fix it

Session A: lock playlist 1, then 2. Session B: lock playlist 2, then 1. Observe `deadlock_detected`. Fix by acquiring locks in a deterministic order (smallest id first).

## 10. Serializable money: the upgrade race

Two transactions read a user's `subscription`, both decide to upgrade, both write. At READ COMMITTED both succeed (lost update). At SERIALIZABLE, one fails with `40001` and must retry.

## 11. Index practice — measure before/after

Take a slow query (`EXPLAIN ANALYZE`), add an index, re-measure. Don't add indexes you can't justify with numbers.

## 12. Top-N report at REPEATABLE READ

Generate a "top 100 most-played songs of the last hour" report inside a REPEATABLE READ transaction so the result is internally consistent even if writes pour in.

## How to approach each

1. Read the relevant `docs/` page first.
2. Open the corresponding stub in `practice/`.
3. Write the SQL. Run it. Read errors carefully.
4. Add `EXPLAIN` / `\timing` to confirm it does what you think.
5. Don't peek at solutions — there aren't any. The schema and your logic are the answer key.
