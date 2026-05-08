-- Exercise 07 — Playlists with more than 4 songs
--
-- Find playlists that contain MORE THAN 4 songs (compute the count from
-- playlist_songs — do NOT trust the cached song_count column).
-- Columns (in this order):
--     playlist_name, owner_username, n_songs
-- Order by n_songs DESC, then playlist_name ASC.

-- Your code here:
SELECT playlists.name AS playlist_name, users.username AS owner_username, COUNT(playlist_songs.song_id) AS n_songs
FROM playlists
JOIN users ON users.user_id = playlists.user_id
JOIN playlist_songs ON playlist_songs.playlist_id = playlists.playlist_id
GROUP BY playlists.playlist_id, playlists.name, users.user_id, users.username
HAVING COUNT(playlist_songs.song_id) > 4
ORDER BY n_songs DESC, playlist_name ASC
