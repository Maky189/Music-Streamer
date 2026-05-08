-- File: practice/indexes/04-find-unused.sql
-- Objective: Audit which indexes are actually used; drop the dead ones.
--
-- TODO:
--   Run a diverse workload first (the queries from 01-explain-baseline.sql, multiple times).
--
--   1. List every index and its scan count:
--        SELECT schemaname, relname AS table, indexrelname AS index, idx_scan
--        FROM pg_stat_user_indexes
--        ORDER BY idx_scan ASC, relname;
--
--   2. List indexes that have NEVER been scanned (idx_scan = 0) — candidates for removal.
--
--   3. Find duplicate / overlapping indexes:
--        SELECT indrelid::regclass AS table,
--               array_agg(indexrelid::regclass) AS overlapping
--        FROM pg_index
--        GROUP BY indrelid, indkey
--        HAVING COUNT(*) > 1;
--
-- TODO action:
--   - Drop one index you've decided is unused. Re-run your benchmark queries to confirm
--     nothing regressed. If something did regress, recreate the index — measurements > guesses.

-- Your code here:

SELECT schemaname,
       relname AS table_name,
       indexrelname AS index_name,
       idx_scan AS times_scanned,
       idx_tup_read AS tuples_read,
       idx_tup_fetch AS tuples_fetched
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC, relname;

SELECT schemaname,
       relname AS table_name,
       indexrelname AS index_name,
       pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;

WITH index_info AS (
    SELECT t.relname AS table_name,
           i.relname AS index_name,
           a.attname AS column_name,
           ix.indkey::text AS index_columns
    FROM pg_class t
    JOIN pg_index idx ON t.oid = idx.indrelid
    JOIN pg_class i ON i.oid = idx.indexrelid
    JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(idx.indkey)
    JOIN pg_indexes ix ON ix.indexname = i.relname
)
SELECT table_name,
       array_agg(index_name ORDER BY index_name) AS overlapping_indexes,
       index_columns,
       COUNT(*) AS count
FROM index_info
GROUP BY table_name, index_columns
HAVING COUNT(*) > 1
ORDER BY table_name, index_columns;

-- ===== Remove an unused index and verify no regression =====
-- Example: drop a specific unused index
-- DROP INDEX idx_name;

-- Then re-run critical queries to confirm performance is acceptable
-- EXPLAIN ANALYZE SELECT * FROM songs WHERE album_id = 17;
-- EXPLAIN ANALYZE SELECT * FROM play_history WHERE user_id = 1 ORDER BY played_at DESC LIMIT 20;

-- If regression occurs, recreate it:
-- CREATE INDEX idx_name ON table(column);

