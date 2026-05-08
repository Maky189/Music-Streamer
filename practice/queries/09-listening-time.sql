-- Exercise 09 — Total listening time per user
--
-- Sum seconds_listened from play_history per user. Only include users who
-- have at least one play_history row.
-- Columns (in this order):
--     username, total_seconds
-- Order by total_seconds DESC, then username ASC.

-- Your code here:
SELECT users.username, SUM(play_history.seconds_listened) AS total_seconds
FROM users
JOIN play_history ON play_history.user_id = users.user_id
GROUP BY users.user_id, users.username
ORDER BY total_seconds DESC, users.username ASC
