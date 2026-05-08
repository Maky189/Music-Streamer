-- Exercise 04 — Top 5 most-played songs
--
-- Return the 5 songs with the highest play_count.
-- Columns (in this order):
--     title, artist_name, play_count
-- Order by play_count DESC. Tie-break by title ASC.

-- Your code here:
SELECT songs.title, artists.name AS artist_name, songs.play_count
FROM songs
JOIN albums ON songs.album_id = albums.album_id
JOIN artists ON albums.artist_id = artists.artist_id
ORDER BY songs.play_count DESC, songs.title ASC
LIMIT 5
