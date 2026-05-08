-- File: practice/procedures/01-add-song-to-playlist.sql
-- Objective: Stored procedure that adds a song to a playlist atomically.
--
-- TODO:
--   Create PROCEDURE add_song_to_playlist(p_playlist_id INT, p_song_id INT)
--     1. Compute next position = MAX(position)+1 for the playlist.
--     2. INSERT INTO playlist_songs (playlist_id, song_id, position).
--     3. UPDATE playlists SET song_count = song_count + 1, modified_at = NOW()
--        WHERE playlist_id = p_playlist_id.
--   Handle:
--     - unique_violation (song already in playlist) → RAISE NOTICE and return without error.
--     - foreign_key_violation → RAISE EXCEPTION 'invalid playlist or song'.
--
-- TODO test:
--   CALL add_song_to_playlist(1, 50);
--   CALL add_song_to_playlist(1, 50);   -- second call should be a no-op with a notice.
--   SELECT song_count FROM playlists WHERE playlist_id = 1;

-- Your code here:
CREATE OR REPLACE PROCEDURE add_song_to_playlist(
    p_playlist_id INT,
    p_song_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_next_position INT;
BEGIN
    SELECT COALESCE(MAX(position), 0) + 1 INTO v_next_position
    FROM playlist_songs
    WHERE playlist_id = p_playlist_id;

    INSERT INTO playlist_songs (playlist_id, song_id, position)
    VALUES (p_playlist_id, p_song_id, v_next_position);

    UPDATE playlists
    SET song_count = song_count + 1,
        modified_at = NOW()
    WHERE playlist_id = p_playlist_id;

    RAISE NOTICE 'Song % added to playlist % at position %', p_song_id, p_playlist_id, v_next_position;

EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Song % is already in playlist %', p_song_id, p_playlist_id;
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'Invalid playlist % or song %', p_playlist_id, p_song_id;
END $$;

-- Test calls:
-- CALL add_song_to_playlist(1, 50);
-- CALL add_song_to_playlist(1, 50);   -- Should show "already in playlist" notice
-- SELECT song_count FROM playlists WHERE playlist_id = 1;

