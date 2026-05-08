-- File: practice/procedures/02-create-playlist.sql
-- Objective: Procedure that creates a playlist and adds an initial set of songs in one transaction.
--
-- TODO:
--   Create PROCEDURE create_playlist_with_songs(
--       p_user_id INT,
--       p_name    VARCHAR,
--       p_song_ids INT[]
--   )
--     1. INSERT a new playlist (RETURNING playlist_id into a variable).
--     2. UNNEST p_song_ids WITH ORDINALITY and bulk-insert into playlist_songs.
--     3. UPDATE playlists.song_count to array_length(p_song_ids, 1).
--   The whole thing must roll back if ANY song_id is invalid.
--
-- TODO test:
--   CALL create_playlist_with_songs(1, 'New Mix', ARRAY[1,2,3,4]);
--   CALL create_playlist_with_songs(1, 'Bad Mix', ARRAY[1,2,9999999]);  -- expect failure

-- Your code here:
CREATE OR REPLACE PROCEDURE create_playlist_with_songs(
    p_user_id INT,
    p_name VARCHAR,
    p_song_ids INT[]
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_playlist_id INT;
    v_song_count INT;
BEGIN
    INSERT INTO playlists (user_id, name, created_at, modified_at, song_count)
    VALUES (p_user_id, p_name, NOW(), NOW(), 0)
    RETURNING playlist_id INTO v_playlist_id;

    INSERT INTO playlist_songs (playlist_id, song_id, position)
    SELECT v_playlist_id, song_id, position
    FROM UNNEST(p_song_ids) WITH ORDINALITY AS t(song_id, position);

    v_song_count := array_length(p_song_ids, 1);

    UPDATE playlists
    SET song_count = v_song_count
    WHERE playlist_id = v_playlist_id;

    RAISE NOTICE 'Playlist % created with % songs', v_playlist_id, v_song_count;

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'One or more song IDs are invalid';
    WHEN others THEN
        RAISE EXCEPTION 'Error creating playlist: %', SQLERRM;
END $$;

-- Test calls:
-- CALL create_playlist_with_songs(1, 'New Mix', ARRAY[1, 2, 3, 4]);
-- CALL create_playlist_with_songs(1, 'Bad Mix', ARRAY[1, 2, 9999999]);  -- Should fail on invalid song

