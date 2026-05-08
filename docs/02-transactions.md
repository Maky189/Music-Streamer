# Transactions

A **transaction** is a unit of work that the database treats atomically.

## Syntax (PostgreSQL)

```sql
BEGIN;                         -- or: START TRANSACTION;
  -- ... statements ...
COMMIT;                        -- make changes permanent
-- or
ROLLBACK;                      -- discard everything since BEGIN
```

MySQL is identical except `START TRANSACTION` is preferred and you may need `SET autocommit = 0;`.

## Savepoints — partial rollback

```sql
BEGIN;
  INSERT INTO playlists ...;
  SAVEPOINT after_playlist;

  INSERT INTO playlist_songs ...;   -- risky
  ROLLBACK TO SAVEPOINT after_playlist;   -- undo only the song insert

  COMMIT;
```

Savepoints are essential when you want to *try* something inside a larger transaction without throwing the whole thing away.

## Error handling

PostgreSQL aborts the transaction on the first error — every subsequent statement returns `current transaction is aborted`. You must `ROLLBACK` (or rollback to a savepoint) before continuing.

```sql
BEGIN;
  SAVEPOINT s1;
  INSERT INTO songs (...);   -- might fail (CHECK violation)
  -- if it failed:
  ROLLBACK TO SAVEPOINT s1;
  -- now you can keep going
COMMIT;
```

## Implicit transactions

Every standalone statement runs in its own transaction (autocommit). `BEGIN` only matters when you need to group ≥2 statements.

## Common pitfalls

| Pitfall | What goes wrong |
|---------|-----------------|
| Long-running tx | Holds locks, bloats WAL, blocks vacuum. Keep transactions short. |
| Mixing reads with slow user input inside a tx | A user pressing "send" 10 minutes later still holds row locks. |
| Forgetting `COMMIT` in a script | Your psql session may roll back on disconnect. |
| Catching errors and continuing without `ROLLBACK TO SAVEPOINT` | Every later statement just errors out. |

## Use cases in this project

- Transferring a playlist between users (delete + insert + audit log).
- Adding a song to a playlist (insert into `playlist_songs` + bump `playlists.song_count`).
- Batch-importing songs with all-or-nothing semantics.
