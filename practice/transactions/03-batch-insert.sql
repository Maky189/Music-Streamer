-- File: practice/transactions/03-batch-insert.sql
-- Objective: Insert an artist + album + several songs as one atomic unit.
--
-- TODO:
--   1. BEGIN.
--   2. INSERT a new artist (RETURNING artist_id INTO a variable).
--   3. INSERT a new album for that artist (RETURNING album_id).
--   4. INSERT 5 songs for that album.
--   5. COMMIT.
--
-- TODO failure path:
--   - Repeat the same block but make the 4th song violate a CHECK constraint
--     (e.g. duration_seconds = 0).
--   - Confirm that NONE of the rows landed (artist, album, earlier songs all rolled back).
--
-- Hint: wrap the body in a DO $$ DECLARE ... BEGIN ... END $$ block so you can use variables.

-- Your code here:

