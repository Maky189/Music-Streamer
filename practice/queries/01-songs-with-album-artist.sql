-- Exercise 01 — All songs with their album and artist
--
-- Return every song with its album title and the artist's name.
-- Columns (in this exact order):
--     song_id, song_title, album_title, artist_name
-- Order by song_id ASC.
--
-- Tables: songs, albums, artists.

-- Your code here:
select songs.song_id, songs.title, albums.title, artists.name from albums join artists on albums.artist_id = artists.artist_id join songs on songs.album_id = albums.album_id order by songs.song_id asc

