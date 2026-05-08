-- Exercise 05 — Users who own at least one playlist
--
-- Return the usernames of users who own one or more playlists.
-- Each username must appear exactly once.
-- Columns:
--     username
-- Order by username ASC.

-- Your code here:
SELECT DISTINCT users.username
FROM users
JOIN playlists ON playlists.user_id = users.user_id
ORDER BY users.username ASC
