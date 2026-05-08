-- Exercise 15 — Albums whose songs are longer than the global average
--
-- The global average is AVG(duration_seconds) over EVERY song in the songs
-- table. Find every album whose own AVG(duration_seconds) is strictly
-- greater than that global average.
--
-- Columns (in this order):
--     album_title, avg_duration
-- avg_duration is the album's average rounded to the nearest integer.
-- Order by avg_duration DESC, then album_title ASC.
--
-- Hint: a scalar subquery in HAVING, e.g.
--     HAVING AVG(s.duration_seconds) > (SELECT AVG(duration_seconds) FROM songs)

-- Your code here:
SELECT albums.title AS album_title, ROUND(AVG(songs.duration_seconds))::int AS avg_duration
FROM albums
JOIN songs ON songs.album_id = albums.album_id
GROUP BY albums.album_id, albums.title
HAVING AVG(songs.duration_seconds) > (SELECT AVG(duration_seconds) FROM songs)
ORDER BY avg_duration DESC, album_title ASC
