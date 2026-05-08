-- Exercise 06 — Albums whose songs are long on average
--
-- For each album whose AVERAGE song duration is strictly greater than 250
-- seconds, return the album title and the average duration ROUNDED to the
-- nearest integer.
-- Columns (in this order):
--     album_title, avg_duration
-- Order by avg_duration DESC, then album_title ASC.
--
-- Hint: ROUND(AVG(...))::int

-- Your code here:
SELECT albums.title AS album_title, ROUND(AVG(songs.duration_seconds))::int AS avg_duration
FROM albums
JOIN songs ON songs.album_id = albums.album_id
GROUP BY albums.album_id, albums.title
HAVING AVG(songs.duration_seconds) > 250
ORDER BY avg_duration DESC, album_title ASC
