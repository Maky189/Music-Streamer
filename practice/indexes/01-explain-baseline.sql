-- File: practice/indexes/01-explain-baseline.sql
-- Objective: Get comfortable reading EXPLAIN / EXPLAIN ANALYZE output BEFORE adding indexes.
--
-- TODO:
--   For each query below, run:
--       EXPLAIN ANALYZE <query>;
--   Record the planner choice (Seq Scan / Index Scan / Bitmap), total time, and row count.
--
--   Q1.  SELECT * FROM songs WHERE album_id = 17;
--   Q2.  SELECT * FROM play_history WHERE user_id = 1 ORDER BY played_at DESC LIMIT 20;
--   Q3.  SELECT * FROM users WHERE LOWER(email) = 'alice@example.com';
--   Q4.  SELECT * FROM songs WHERE title ILIKE '%neon%';
--   Q5.  SELECT COUNT(*) FROM playlist_songs WHERE song_id = 42;
--
-- TODO journal:
--   - Which queries already use an index? Which fall back to Seq Scan? Why?
--   - Save the times — you'll compare them in the next exercise.

-- Your code here:

EXPLAIN ANALYZE
SELECT * FROM songs WHERE album_id = 17;

EXPLAIN ANALYZE
SELECT * FROM play_history WHERE user_id = 1 ORDER BY played_at DESC LIMIT 20;

EXPLAIN ANALYZE
SELECT * FROM users WHERE LOWER(email) = 'alice@example.com';

EXPLAIN ANALYZE
SELECT * FROM songs WHERE title ILIKE '%neon%';

EXPLAIN ANALYZE
SELECT COUNT(*) FROM playlist_songs WHERE song_id = 42;

