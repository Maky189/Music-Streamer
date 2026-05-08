-- File: practice/indexes/02-create-and-measure.sql
-- Objective: Create indexes that improve the queries from 01-explain-baseline.sql, and prove it.
--
-- TODO:
--   For each query, decide what index would help, CREATE it, then re-run EXPLAIN ANALYZE.
--   Confirm the plan changed AND the time dropped.
--
--   Q3.  Expression index — CREATE INDEX ... ON users (LOWER(email));
--   Q4.  Trigram or GIN — requires `CREATE EXTENSION IF NOT EXISTS pg_trgm;`
--          then  CREATE INDEX ... ON songs USING GIN (title gin_trgm_ops);
--   Q5.  Already covered by idx_playlist_songs_song from the schema — verify.
--
--   Also try:
--   - Index for top-N: CREATE INDEX ... ON songs(play_count DESC);
--   - Composite: CREATE INDEX ... ON play_history(user_id, played_at DESC);
--
-- TODO journal:
--   - Compare timings before/after for each query.
--   - Which indexes hurt write throughput most? (Try INSERT 1000 songs in a loop and time it.)

-- Your code here:

CREATE INDEX idx_users_email_ci ON users (LOWER(email));

EXPLAIN ANALYZE
SELECT * FROM users WHERE LOWER(email) = 'alice@example.com';

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX idx_songs_title_trigram ON songs USING GIN (title gin_trgm_ops);

EXPLAIN ANALYZE
SELECT * FROM songs WHERE title ILIKE '%neon%';

EXPLAIN ANALYZE
SELECT COUNT(*) FROM playlist_songs WHERE song_id = 42;

CREATE INDEX idx_play_history_user_played ON play_history(user_id, played_at DESC);

EXPLAIN ANALYZE
SELECT * FROM play_history WHERE user_id = 1 ORDER BY played_at DESC LIMIT 20;

CREATE INDEX idx_songs_playcount_desc ON songs(play_count DESC);

EXPLAIN ANALYZE
SELECT song_id, title, play_count FROM songs ORDER BY play_count DESC LIMIT 10;

