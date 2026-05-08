-- Exercise 02 — Songs longer than 4 minutes
--
-- Return all songs whose duration is strictly greater than 240 seconds,
-- along with the artist name.
-- Columns (in this order):
--     title, artist_name, duration_seconds
-- Order by duration_seconds DESC, then title ASC.

-- Your code here:
SELECT songs.title, artists.name AS artist_name, songs.duration_seconds
FROM songs
JOIN albums ON songs.album_id = albums.album_id
JOIN artists ON albums.artist_id = artists.artist_id
WHERE songs.duration_seconds > 240
ORDER BY songs.duration_seconds DESC, songs.title ASC

