-- File: practice/indexes/03-partial-and-expression.sql
-- Objective: Use partial and expression indexes for narrow-purpose speedups.
--
-- TODO partial:
--   Most session lookups only care about active sessions:
--     SELECT * FROM user_sessions WHERE is_active AND user_id = 1;
--   Create a PARTIAL index:
--     CREATE INDEX idx_active_sessions_user
--       ON user_sessions(user_id) WHERE is_active;
--   Run EXPLAIN ANALYZE before & after.
--
-- TODO expression:
--   Case-insensitive username search:
--     SELECT * FROM users WHERE LOWER(username) = 'alice';
--   Create:
--     CREATE INDEX idx_users_username_ci ON users (LOWER(username));
--   Confirm the planner picks it up only when the WHERE matches the expression exactly.
--
-- TODO covering / INCLUDE:
--   For:  SELECT song_id, title FROM songs WHERE album_id = 17;
--   Try:  CREATE INDEX idx_songs_album_cov ON songs(album_id) INCLUDE (title);
--   This enables index-only scans. Confirm with EXPLAIN ANALYZE.

-- Your code here:

EXPLAIN ANALYZE
SELECT * FROM user_sessions WHERE is_active AND user_id = 1;

CREATE INDEX idx_active_sessions_user
  ON user_sessions(user_id)
  WHERE is_active = TRUE;

EXPLAIN ANALYZE
SELECT * FROM user_sessions WHERE is_active AND user_id = 1;

EXPLAIN ANALYZE
SELECT * FROM user_sessions WHERE is_active = FALSE AND user_id = 1;

EXPLAIN ANALYZE
SELECT * FROM users WHERE LOWER(username) = 'alice';

CREATE INDEX idx_users_username_ci ON users (LOWER(username));

EXPLAIN ANALYZE
SELECT * FROM users WHERE LOWER(username) = 'alice';

EXPLAIN ANALYZE
SELECT * FROM users WHERE username = 'alice';

EXPLAIN ANALYZE
SELECT song_id, title FROM songs WHERE album_id = 17;

CREATE INDEX idx_songs_album_cov ON songs(album_id) INCLUDE (title);

EXPLAIN ANALYZE
SELECT song_id, title FROM songs WHERE album_id = 17;

EXPLAIN ANALYZE
SELECT song_id, title, duration_seconds FROM songs WHERE album_id = 17;

