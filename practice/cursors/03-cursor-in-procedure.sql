-- File: practice/cursors/03-cursor-in-procedure.sql
-- Objective: Combine a cursor with a stored procedure for batch maintenance.
--
-- TODO:
--   Create PROCEDURE expire_inactive_users(p_months INT)
--     - Iterate (with a cursor) over users whose latest play_history is older than p_months
--       OR who have no play_history at all.
--     - For each such user:
--         UPDATE users SET subscription = 'free' WHERE user_id = rec.user_id;
--         UPDATE user_sessions SET is_active = FALSE WHERE user_id = rec.user_id;
--         INSERT a row into audit_log describing the expiration.
--   Use proper exception handling so a single failing user doesn't kill the whole run
--   (hint: BEGIN / EXCEPTION inside the loop, or SAVEPOINT per row).
--
-- TODO test:
--   CALL expire_inactive_users(12);

-- Your code here:
CREATE OR REPLACE PROCEDURE expire_inactive_users(p_months INT)
LANGUAGE plpgsql
AS $$
DECLARE
    cur CURSOR FOR
        SELECT u.user_id, u.username
        FROM users u
        LEFT JOIN play_history ph ON u.user_id = ph.user_id
        GROUP BY u.user_id, u.username
        HAVING MAX(ph.played_at) < NOW() - INTERVAL '1 month' * p_months
               OR MAX(ph.played_at) IS NULL;
    rec RECORD;
BEGIN
    OPEN cur;
    LOOP
        FETCH cur INTO rec;
        EXIT WHEN NOT FOUND;

        BEGIN
            UPDATE users SET subscription = 'free' WHERE user_id = rec.user_id;
            UPDATE user_sessions SET is_active = FALSE WHERE user_id = rec.user_id;
            INSERT INTO audit_log (user_id, action, details, timestamp)
            VALUES (rec.user_id, 'EXPIRE_INACTIVE', 'User subscription downgraded to free', NOW());
            RAISE NOTICE 'Expired user: % (%)', rec.username, rec.user_id;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Error processing user %: %', rec.user_id, SQLERRM;
        END;
    END LOOP;
    CLOSE cur;
    RAISE NOTICE 'Inactive user expiration completed';
END $$;

