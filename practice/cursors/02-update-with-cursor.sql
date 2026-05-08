-- File: practice/cursors/02-update-with-cursor.sql
-- Objective: Update rows row-by-row using a cursor with WHERE CURRENT OF.
--
-- TODO:
--   1. DECLARE cur CURSOR FOR SELECT song_id, duration_seconds FROM songs
--                              WHERE duration_seconds < 60 FOR UPDATE.
--   2. OPEN, LOOP, FETCH.
--   3. For each row, DELETE WHERE CURRENT OF cur (treat <60s as a bug to clean up).
--   4. CLOSE.
--   5. RAISE NOTICE the total number of deletes (use a counter variable).
--
-- TODO compare:
--   Write the equivalent set-based DELETE in one statement. Time both with \timing.
--   Which one would you ship to production, and why?

-- Your code here:
DO $$
DECLARE
    cur CURSOR FOR SELECT song_id, duration_seconds
                   FROM songs
                   WHERE duration_seconds < 60
                   FOR UPDATE;
    rec RECORD;
    delete_count INT := 0;
BEGIN
    OPEN cur;
    LOOP
        FETCH cur INTO rec;
        EXIT WHEN NOT FOUND;
        DELETE FROM songs WHERE CURRENT OF cur;
        delete_count := delete_count + 1;
    END LOOP;
    CLOSE cur;
    RAISE NOTICE 'Total songs deleted (duration < 60s): %', delete_count;
END $$;

