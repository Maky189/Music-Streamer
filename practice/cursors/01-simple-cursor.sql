-- File: practice/cursors/01-simple-cursor.sql
-- Objective: Iterate over a result set with an explicit cursor.
--
-- TODO:
--   Inside a DO $$ ... $$ block:
--     1. DECLARE a CURSOR FOR SELECT song_id, title, duration_seconds
--                              FROM songs WHERE play_count > 1000000
--                              ORDER BY play_count DESC.
--     2. OPEN it.
--     3. LOOP / FETCH / EXIT WHEN NOT FOUND.
--     4. RAISE NOTICE one line per row.
--     5. CLOSE.
--
-- TODO bonus:
--   - Re-implement the same logic with FOR rec IN <query> LOOP and notice how much shorter it is.
--   - Run EXPLAIN on the underlying SELECT to see the plan.

-- Your code here:
DO $$
DECLARE
    cur CURSOR FOR SELECT song_id, title, duration_seconds
                   FROM songs
                   WHERE play_count > 1000000
                   ORDER BY play_count DESC;
    rec RECORD;
BEGIN
    OPEN cur;
    LOOP
        FETCH cur INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Song ID: %, Title: %, Duration: %s', rec.song_id, rec.title, rec.duration_seconds;
    END LOOP;
    CLOSE cur;
END $$;

