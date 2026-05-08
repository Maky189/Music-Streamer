-- File: practice/procedures/03-calculate-stats.sql
-- Objective: Function that returns aggregate statistics for a user.
--
-- TODO:
--   Create FUNCTION user_stats(p_user_id INT)
--   RETURNS TABLE(
--       total_plays      BIGINT,
--       total_seconds    BIGINT,
--       favorite_genre   VARCHAR,
--       playlists_owned  INT,
--       last_played_at   TIMESTAMP
--   )
--   that joins users → play_history → songs → albums → artists.
--
--   - favorite_genre = artist genre with the highest play count for this user.
--   - last_played_at = MAX(played_at) from play_history for this user.
--
-- TODO test:
--   SELECT * FROM user_stats(1);

-- Your code here:
CREATE OR REPLACE FUNCTION user_stats(p_user_id INT)
RETURNS TABLE(
    total_plays BIGINT,
    total_seconds BIGINT,
    favorite_genre VARCHAR,
    playlists_owned INT,
    last_played_at TIMESTAMP
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(COUNT(ph.play_id)::BIGINT, 0) AS total_plays,
        COALESCE(SUM(s.duration_seconds)::BIGINT, 0) AS total_seconds,
        (SELECT a.genre
         FROM play_history ph2
         JOIN songs s2 ON ph2.song_id = s2.song_id
         JOIN albums al ON s2.album_id = al.album_id
         JOIN artists a ON al.artist_id = a.artist_id
         WHERE ph2.user_id = p_user_id
         GROUP BY a.genre
         ORDER BY COUNT(*) DESC
         LIMIT 1) AS favorite_genre,
        (SELECT COUNT(*)::INT
         FROM playlists
         WHERE user_id = p_user_id) AS playlists_owned,
        MAX(ph.played_at) AS last_played_at
    FROM play_history ph
    JOIN songs s ON ph.song_id = s.song_id
    WHERE ph.user_id = p_user_id;
END $$;

-- Test call:
-- SELECT * FROM user_stats(1);

