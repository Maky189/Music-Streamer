-- Exercise 10 — Users who never appear in play_history
--
-- Return the usernames of users with ZERO entries in play_history.
-- Columns:
--     username
-- Order by username ASC.

-- Your code here:
SELECT users.username
FROM users
LEFT JOIN play_history ON play_history.user_id = users.user_id
WHERE play_history.user_id IS NULL
ORDER BY users.username ASC
