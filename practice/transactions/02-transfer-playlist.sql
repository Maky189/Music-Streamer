-- File: practice/transactions/02-transfer-playlist.sql
-- Objective: Transfer ownership of a playlist between users atomically.
--
-- TODO:
--   1. BEGIN a transaction.
--   2. UPDATE playlists SET user_id = <new_owner> WHERE playlist_id = <id>.
--   3. INSERT a row into audit_log describing the transfer
--      (table_name='playlists', operation='UPDATE', payload as JSONB with old/new user_id).
--   4. COMMIT.
--
-- TODO bonus:
--   - Make the transfer fail (e.g. transfer to a user_id that does not exist) and observe that
--     the audit_log insert is also rolled back.
--   - Re-write using RAISE EXCEPTION inside a DO $$ ... $$ block to abort on a business rule
--     ("cannot transfer a playlist to its current owner").
--
-- Hints: to_jsonb(), CURRENT_TIMESTAMP, ROLLBACK.

-- Your code here:

