-- Exercise 14 — Pairs of users with overlapping listening
--
-- Find pairs of users (u1, u2) where BOTH have at least one play_history
-- row for the SAME song. Count how many distinct songs they share.
-- Avoid duplicates: only include each unordered pair once by requiring
-- u1.user_id < u2.user_id.
--
-- Columns (in this order):
--     user1_username, user2_username, shared_songs
-- Order by shared_songs DESC, then user1_username ASC, then user2_username ASC.
-- LIMIT to the top 10 pairs.
--
-- Hint: self-join play_history on song_id, COUNT(DISTINCT song_id), etc.

-- Your code here:
SELECT
  u1.username AS user1_username,
  u2.username AS user2_username,
  COUNT(DISTINCT ph1.song_id) AS shared_songs
FROM play_history ph1
JOIN play_history ph2 ON ph1.song_id = ph2.song_id AND ph1.user_id < ph2.user_id
JOIN users u1 ON u1.user_id = ph1.user_id
JOIN users u2 ON u2.user_id = ph2.user_id
GROUP BY ph1.user_id, ph2.user_id, u1.username, u2.username
ORDER BY shared_songs DESC, u1.username ASC, u2.username ASC
LIMIT 10
