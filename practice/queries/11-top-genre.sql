-- Exercise 11 — The genre with the highest total play_count
--
-- Sum songs.play_count grouped by artist genre, and return the SINGLE
-- genre with the largest total.
-- Columns (in this order):
--     genre, total_plays
-- Exactly one row in the result.

-- Your code here:
SELECT artists.genre, SUM(songs.play_count) AS total_plays
FROM artists
JOIN albums ON albums.artist_id = artists.artist_id
JOIN songs ON songs.album_id = albums.album_id
GROUP BY artists.genre
ORDER BY total_plays DESC
LIMIT 1
