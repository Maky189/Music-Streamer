# Triggers

A **trigger** is code that fires automatically in response to `INSERT`, `UPDATE`, `DELETE`, or `TRUNCATE` on a table.

## Anatomy (PostgreSQL)

A PG trigger is two things: a **function** returning `TRIGGER`, and the trigger that ties the function to a table + event.

```sql
CREATE OR REPLACE FUNCTION fn_audit_songs()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO audit_log(table_name, operation, row_pk, payload)
    VALUES ('songs', TG_OP, COALESCE(NEW.song_id, OLD.song_id)::text,
            to_jsonb(COALESCE(NEW, OLD)));
    RETURN COALESCE(NEW, OLD);
END $$;

CREATE TRIGGER trg_audit_songs
AFTER INSERT OR UPDATE OR DELETE ON songs
FOR EACH ROW EXECUTE FUNCTION fn_audit_songs();
```

## Timing × granularity

| Timing  | Granularity  | When you'd use it |
|---------|--------------|-------------------|
| BEFORE  | FOR EACH ROW  | Validate / mutate `NEW` before write. |
| AFTER   | FOR EACH ROW  | Audit log, side effects, cascading writes. |
| BEFORE  | FOR EACH STATEMENT | Block disallowed bulk ops. |
| AFTER   | FOR EACH STATEMENT | Refresh materialized views, summary stats. |
| INSTEAD OF | FOR EACH ROW (views only) | Make a view writable. |

## OLD / NEW

- `INSERT`: `NEW` populated, `OLD` is NULL.
- `UPDATE`: both populated.
- `DELETE`: `OLD` populated, `NEW` is NULL.
- Available variables: `TG_OP` ('INSERT'/'UPDATE'/'DELETE'), `TG_TABLE_NAME`, `TG_WHEN`, `TG_LEVEL`.

## Returning from BEFORE triggers

- Return `NULL` to **cancel** the operation for that row.
- Return a modified `NEW` to substitute it.

```sql
CREATE OR REPLACE FUNCTION fn_set_modified_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.modified_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_users_modified
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION fn_set_modified_at();
```

## Common patterns

- **Audit log** — write `OLD`/`NEW` snapshots to a history table.
- **Auto timestamps** — keep `modified_at` honest without trusting the app.
- **Validation** — reject rows that violate rules too dynamic for a `CHECK` constraint.
- **Maintaining derived columns** — keep `playlists.song_count` in sync with `playlist_songs`.
- **Cascading soft deletes** — set `is_active = FALSE` on dependent rows.

## Pitfalls

- Triggers are **invisible**. A new dev wonders why `INSERT` is mysteriously slow or why a row magically appears in another table. Document them.
- Recursive triggers can self-fire and infinite loop. Use `pg_trigger_depth()` to guard.
- Triggers run inside the calling transaction — a slow trigger slows every write.
- Statement-level triggers don't see per-row OLD/NEW; use **transition tables** (`REFERENCING OLD TABLE AS ...`) if you need them.

## MySQL differences

MySQL triggers don't separate the function from the trigger:

```sql
DELIMITER //
CREATE TRIGGER trg_users_modified
BEFORE UPDATE ON users
FOR EACH ROW
BEGIN
    SET NEW.modified_at = NOW();
END //
DELIMITER ;
```

Only `BEFORE`/`AFTER`, no `INSTEAD OF`. One trigger per (timing, event, table) prior to MySQL 5.7.2.
