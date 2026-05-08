-- File: practice/cursors/04-nested-cursors.sql
-- Objective: Practice nested cursors (artist → albums → songs).
--
-- TODO:
--   Inside a DO $$ ... $$ block:
--     - Outer cursor: SELECT artist_id, name FROM artists ORDER BY name.
--     - Middle cursor (parameterized): SELECT album_id, title FROM albums WHERE artist_id = $1.
--     - Inner cursor (parameterized): SELECT title, duration_seconds FROM songs WHERE album_id = $1.
--     - Print a tree:
--         Artist Foo
--           Album Bar (2021)
--             - Track 1 (213s)
--             - Track 2 (180s)
--
-- TODO compare:
--   Achieve the same output with a single SELECT + ORDER BY using string concatenation or
--   GROUP BY + array_agg. Notice how unmaintainable the cursor version is by comparison.

-- Your code here:
DO $$
DECLARE
    artist_cur CURSOR FOR SELECT artist_id, name FROM artists ORDER BY name;
    album_cur CURSOR(artist_id_param INT) FOR SELECT album_id, title, release_year FROM albums WHERE artist_id = artist_id_param ORDER BY release_year DESC;
    song_cur CURSOR(album_id_param INT) FOR SELECT title, duration_seconds FROM songs WHERE album_id = album_id_param ORDER BY title;

    artist_rec RECORD;
    album_rec RECORD;
    song_rec RECORD;
BEGIN
    OPEN artist_cur;
    LOOP
        FETCH artist_cur INTO artist_rec;
        EXIT WHEN NOT FOUND;

        RAISE NOTICE 'Artist: %', artist_rec.name;

        OPEN album_cur(artist_rec.artist_id);
        LOOP
            FETCH album_cur INTO album_rec;
            EXIT WHEN NOT FOUND;

            RAISE NOTICE '  Album: % (%)', album_rec.title, album_rec.release_year;

            OPEN song_cur(album_rec.album_id);
            LOOP
                FETCH song_cur INTO song_rec;
                EXIT WHEN NOT FOUND;

                RAISE NOTICE '    - % (%s)', song_rec.title, song_rec.duration_seconds;
            END LOOP;
            CLOSE song_cur;
        END LOOP;
        CLOSE album_cur;
    END LOOP;
    CLOSE artist_cur;
END $$;

