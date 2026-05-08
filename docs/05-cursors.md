# Cursors

A **cursor** is a server-side pointer over a query result that you advance one (or N) row at a time. Use it when:

- The result set is too large to materialize in memory.
- You need to apply per-row logic that's awkward in pure SQL.
- You're streaming rows to a client incrementally.

99% of "I need a cursor" cases are better solved with set-based SQL. But cursors *do* have a place.

## PL/pgSQL cursor lifecycle

```
DECLARE  →  OPEN  →  FETCH (loop)  →  CLOSE
```

```sql
DO $$
DECLARE
    cur CURSOR FOR
        SELECT song_id, duration_seconds FROM songs WHERE play_count > 1000;
    rec RECORD;
BEGIN
    OPEN cur;
    LOOP
        FETCH cur INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'song % has duration %', rec.song_id, rec.duration_seconds;
    END LOOP;
    CLOSE cur;
END $$;
```

## The `FOR rec IN query LOOP` shortcut

PL/pgSQL's `FOR ... IN` automatically opens, iterates, and closes a cursor. **Prefer it** unless you genuinely need explicit control.

```sql
DO $$
DECLARE rec RECORD;
BEGIN
    FOR rec IN SELECT song_id FROM songs LOOP
        -- ...
    END LOOP;
END $$;
```

## Updatable cursors (`WHERE CURRENT OF`)

You can `UPDATE` or `DELETE` the row a cursor is currently parked on:

```sql
DECLARE cur CURSOR FOR
    SELECT * FROM songs WHERE play_count = 0 FOR UPDATE;

OPEN cur;
LOOP
    FETCH cur INTO rec;
    EXIT WHEN NOT FOUND;
    DELETE FROM songs WHERE CURRENT OF cur;
END LOOP;
CLOSE cur;
```

## Parametrized cursors

```sql
DECLARE cur CURSOR (min_plays BIGINT) FOR
    SELECT song_id FROM songs WHERE play_count >= min_plays;

OPEN cur(1_000_000);
```

## Holdable cursors

By default a cursor closes at end of transaction. `DECLARE ... CURSOR WITH HOLD` keeps it alive past commit.

## Performance & pitfalls

- A cursor that scans a million rows row-by-row is **far** slower than a single set-based `UPDATE`.
- Don't mix cursor iteration with statements that change the same rows in unpredictable ways.
- Always `CLOSE` (or rely on transaction end). Open cursors hold resources.
- Cursors don't magically reduce I/O — they just spread it over time.

## MySQL cursors

MySQL supports cursors only inside stored procedures, with a stricter lifecycle:

```sql
DECLARE done INT DEFAULT FALSE;
DECLARE cur CURSOR FOR SELECT ...;
DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
OPEN cur;
read_loop: LOOP
    FETCH cur INTO ...;
    IF done THEN LEAVE read_loop; END IF;
END LOOP;
CLOSE cur;
```
