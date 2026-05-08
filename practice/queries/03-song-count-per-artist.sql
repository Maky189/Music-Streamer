-- Exercise 03 — How many songs each artist has
--
-- For every artist, return their name and the number of songs across all
-- their albums. Include artists with zero songs as well (count = 0).
-- Columns (in this order):
--     artist_name, song_count
-- Order by song_count DESC, then artist_name ASC.

-- Your code here:
SELECT artists.name AS artist_name, COUNT(songs.song_id) AS song_count
FROM artists
LEFT JOIN albums ON albums.artist_id = artists.artist_id
LEFT JOIN songs ON songs.album_id = albums.album_id
GROUP BY artists.artist_id, artists.name
ORDER BY COUNT(songs.song_id) DESC, artists.name ASC

