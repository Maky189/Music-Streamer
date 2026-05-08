-- Exercise 08 — Songs that are not in any playlist
--
-- Return every song that does NOT appear in any playlist.
-- Columns (in this order):
--     song_id, title
-- Order by song_id ASC.
--
-- Hint: LEFT JOIN ... WHERE playlist_id IS NULL, or NOT EXISTS (...).

-- Your code here:
SELECT songs.song_id, songs.title
FROM songs
LEFT JOIN playlist_songs ON playlist_songs.song_id = songs.song_id
WHERE playlist_songs.playlist_id IS NULL
ORDER BY songs.song_id ASC
