-- Exercise 12 — Each user's single longest listen
--
-- For every user that has any play_history rows, find the row with the
-- MAXIMUM seconds_listened (their longest single listening session).
-- Return the user, the song they listened to, and how long.
-- If a user has multiple ties, pick the one with the smallest song_id.
-- Columns (in this order):
--     username, song_title, seconds_listened
-- Order by username ASC.
--
-- Hint: window function ROW_NUMBER() OVER (PARTITION BY user_id
--       ORDER BY seconds_listened DESC, song_id ASC), then keep rn = 1.
--       Or a correlated subquery — your call.

-- Your code here:
WITH ranked_listens AS (
  SELECT
    users.username,
    songs.title AS song_title,
    play_history.seconds_listened,
    ROW_NUMBER() OVER (PARTITION BY play_history.user_id ORDER BY play_history.seconds_listened DESC, songs.song_id ASC) AS rn
  FROM play_history
  JOIN users ON users.user_id = play_history.user_id
  JOIN songs ON songs.song_id = play_history.song_id
)
SELECT username, song_title, seconds_listened
FROM ranked_listens
WHERE rn = 1
ORDER BY username ASC
