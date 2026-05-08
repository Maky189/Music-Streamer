-- File: practice/procedures/04-cleanup-empty-playlists.sql
-- Objective: Maintenance procedure that deletes empty playlists older than N days.
--
-- TODO:
--   Create PROCEDURE cleanup_empty_playlists(p_days INT, OUT p_deleted INT)
--     1. DELETE FROM playlists
--        WHERE song_count = 0
--          AND created_at < NOW() - make_interval(days => p_days);
--     2. GET DIAGNOSTICS p_deleted = ROW_COUNT;
--     3. Log the cleanup to audit_log (one summary row).
--
-- TODO test:
--   CALL cleanup_empty_playlists(30, NULL);

-- Your code here:
CREATE OR REPLACE PROCEDURE cleanup_empty_playlists(
    p_days INT,
    OUT p_deleted INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM playlists
    WHERE song_count = 0
      AND created_at < NOW() - make_interval(days => p_days);

    GET DIAGNOSTICS p_deleted = ROW_COUNT;

    INSERT INTO audit_log (user_id, action, details, timestamp)
    VALUES (NULL, 'CLEANUP_EMPTY_PLAYLISTS', 'Deleted ' || p_deleted || ' empty playlists older than ' || p_days || ' days', NOW());

    RAISE NOTICE 'Deleted % empty playlists', p_deleted;
END $$;

-- Test call:
-- CALL cleanup_empty_playlists(30, NULL);

