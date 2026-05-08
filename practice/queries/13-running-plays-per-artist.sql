-- Exercise 13 — Running total of plays for each artist's discography
--
-- For every album, return:
--     - the artist name
--     - the album title
--     - the album's total play_count (sum of its songs)
--     - the running total of play_count across the artist's albums in
--       release_year ASC order (smallest year first)
--
-- Columns (in this order):
--     artist_name, album_title, album_plays, running_total
-- Order by artist_name ASC, then release_year ASC, then album_title ASC.
--
-- Hint:
--     SUM(album_plays) OVER (PARTITION BY artist_id ORDER BY release_year, album_id)

-- Your code here:
WITH album_plays AS (
  SELECT
    artists.artist_id,
    artists.name AS artist_name,
    albums.album_id,
    albums.title AS album_title,
    albums.release_year,
    SUM(songs.play_count) AS album_plays
  FROM albums
  JOIN artists ON artists.artist_id = albums.artist_id
  JOIN songs ON songs.album_id = albums.album_id
  GROUP BY artists.artist_id, artists.name, albums.album_id, albums.title, albums.release_year
)
SELECT
  artist_name,
  album_title,
  album_plays,
  SUM(album_plays) OVER (PARTITION BY artist_id ORDER BY release_year, album_id) AS running_total
FROM album_plays
ORDER BY artist_name ASC, release_year ASC, album_title ASC
