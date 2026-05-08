# Indexes

An **index** is a separate data structure that lets the database find rows without scanning the whole table. Each index speeds up some queries and slows down every write.

## Index types in PostgreSQL

| Type     | Best for                                                  |
|----------|-----------------------------------------------------------|
| **B-tree** (default) | Equality, range (`<`, `>`, `BETWEEN`), `ORDER BY`. |
| **Hash** | Equality only. Rarely worth it over B-tree. |
| **GIN**  | Multi-value columns: `tsvector` (full text), `jsonb`, arrays. |
| **GiST** | Geometric data, `tsvector`, range types. |
| **BRIN** | Huge tables where data is naturally clustered (timestamps, append-only logs). |

## Syntax

```sql
CREATE INDEX idx_songs_album ON songs(album_id);

-- Composite (column order matters: leftmost-prefix rule)
CREATE INDEX idx_play_history_user_played ON play_history(user_id, played_at DESC);

-- Unique index (also enforces uniqueness)
CREATE UNIQUE INDEX uq_users_email ON users(email);

-- Partial index — only some rows
CREATE INDEX idx_active_sessions
  ON user_sessions(user_id) WHERE is_active;

-- Expression index
CREATE INDEX idx_users_email_lower ON users (LOWER(email));

-- GIN on JSONB
CREATE INDEX idx_audit_payload ON audit_log USING GIN (payload);
```

## Reading the plan

```sql
EXPLAIN ANALYZE
SELECT * FROM songs WHERE album_id = 17;
```

Look for:
- `Seq Scan` → no usable index.
- `Index Scan` → the index is being used.
- `Bitmap Index Scan` → multiple indexes combined.
- `actual time` and `rows` to see real cost.

## When indexes help

- Highly selective predicates (a query that returns < ~5% of the table).
- `ORDER BY` matching the index order, especially with `LIMIT`.
- Foreign key columns (PG does **not** auto-index FKs — you must).
- `JOIN` columns on the inner side.

## When indexes hurt

- Tables with heavy `INSERT/UPDATE/DELETE` and few reads.
- Low-cardinality columns (`is_active` alone) — partial indexes are usually better.
- Redundant indexes: `(a)` + `(a, b)` → drop `(a)`, the composite covers it for `WHERE a = ?`.
- Indexes on columns you always wrap in a function (`WHERE LOWER(email) = ?` won't use `(email)`).

## Composite index column order

Rule: most-equality-filtered column first, then range/ordering columns.

```sql
-- Good for queries:  WHERE user_id = 5 ORDER BY played_at DESC
CREATE INDEX ix ON play_history(user_id, played_at DESC);

-- Will NOT efficiently serve: WHERE played_at > now() - interval '1 day'
-- (because user_id is the leftmost column).
```

## Maintenance

- `REINDEX INDEX idx_name;` — rebuild a bloated index.
- `pg_stat_user_indexes` — see which indexes are actually being used (`idx_scan` count).
- Drop unused indexes; they cost write throughput for no read benefit.

## A drill you should do

1. `EXPLAIN ANALYZE` a query — note the time.
2. Create an index you think will help.
3. `EXPLAIN ANALYZE` again — confirm the plan changed.
4. If the plan didn't change or got worse, drop the index.

Indexes are not "more is better." They're "the right ones, justified by measurements."
