-- Verify schema and data loaded correctly.
SELECT 'users'          AS table_name, COUNT(*) FROM users
UNION ALL SELECT 'artists',         COUNT(*) FROM artists
UNION ALL SELECT 'albums',          COUNT(*) FROM albums
UNION ALL SELECT 'songs',           COUNT(*) FROM songs
UNION ALL SELECT 'playlists',       COUNT(*) FROM playlists
UNION ALL SELECT 'playlist_songs',  COUNT(*) FROM playlist_songs
UNION ALL SELECT 'play_history',    COUNT(*) FROM play_history
UNION ALL SELECT 'user_sessions',   COUNT(*) FROM user_sessions
UNION ALL SELECT 'audit_log',       COUNT(*) FROM audit_log;

-- Top 5 artists by total play_count across their songs.
SELECT ar.name, SUM(s.play_count) AS plays
FROM artists ar
JOIN albums  al ON al.artist_id = ar.artist_id
JOIN songs   s  ON s.album_id   = al.album_id
GROUP BY ar.name
ORDER BY plays DESC
LIMIT 5;

-- A playlist with its songs.
SELECT p.name AS playlist, ps.position, s.title, s.duration_seconds
FROM playlists p
JOIN playlist_songs ps ON ps.playlist_id = p.playlist_id
JOIN songs s           ON s.song_id      = ps.song_id
WHERE p.playlist_id = 1
ORDER BY ps.position;
