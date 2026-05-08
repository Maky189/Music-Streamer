-- ============================================================
-- Music Streaming DB — Seed data (real library from ~/Music)
-- ============================================================
-- The 16 song rows below correspond 1:1 to the .mp3 files in the
-- user's ~/Music folder, mounted into the backend container at /music.
-- file_path is relative to that mount.

-- Users (12) ---------------------------------------------------
INSERT INTO users (username, email, country, subscription) VALUES
  ('alice',  'alice@example.com',  'US', 'premium'),
  ('bob',    'bob@example.com',    'US', 'free'),
  ('carol',  'carol@example.com',  'GB', 'premium'),
  ('dave',   'dave@example.com',   'CA', 'family'),
  ('eve',    'eve@example.com',    'DE', 'free'),
  ('frank',  'frank@example.com',  'FR', 'premium'),
  ('grace',  'grace@example.com',  'JP', 'premium'),
  ('heidi',  'heidi@example.com',  'AU', 'free'),
  ('ivan',   'ivan@example.com',   'BR', 'family'),
  ('judy',   'judy@example.com',   'IN', 'free'),
  ('kate',   'kate@example.com',   'PT', 'premium'),
  ('leo',    'leo@example.com',    'PL', 'free');

-- Artists ------------------------------------------------------
INSERT INTO artists (artist_id, name, genre, country, monthly_listeners) VALUES
  (1, 'Dawid Podsiadło',                  'Pop',        'PL',  3_400_000),
  (2, 'Andrew Hulshult & James Paddock',  'Metal',      'US',    180_000),
  (3, 'Andrew Hulshult',                  'Metal',      'US',    420_000),
  (4, 'Mick Gordon',                      'Metal',      'AU',  2_100_000),
  (5, 'Finishing Move',                   'Electronic', 'US',    310_000),
  (6, 'Irina Barros & Mr. Carly',         'Pop',        'PT',     95_000),
  (7, 'Plutonio',                         'Hip-Hop',    'PT',  1_700_000),
  (8, 'Various Artists',                  'Electronic', 'US',     50_000),
  (9, 'Stromae & Pomme',                  'Pop',        'BE',  4_800_000);
SELECT setval('artists_artist_id_seq', (SELECT MAX(artist_id) FROM artists));

-- Albums -------------------------------------------------------
INSERT INTO albums (album_id, artist_id, title, release_year, label) VALUES
  (1,  1, 'Cyberpunk Edgerunners (Soundtrack)',           2022, 'Netflix Music'),
  (2,  2, 'DOOM + DOOM II: Legacy of Rust',               2024, 'id Software'),
  (3,  3, 'Doom Remakes (Andrew Hulshult)',               2017, 'Independent'),
  (4,  4, 'DOOM Eternal (Original Game Soundtrack)',      2020, 'id Software'),
  (5,  5, 'DOOM: The Dark Ages (Original Game Soundtrack)', 2025, 'id Software'),
  (6,  6, 'Singles',                                      2023, 'Independent'),
  (7,  4, 'DOOM (2016 Original Game Soundtrack)',         2016, 'id Software'),
  (8,  7, 'Singles',                                      2022, 'Independent'),
  (9,  8, 'Royalty Free Heavy Metal',                     2021, 'Royalty Free'),
  (10, 9, 'Arcane: League of Legends — Season 2 (Soundtrack)', 2024, 'Riot Games / Universal');
SELECT setval('albums_album_id_seq', (SELECT MAX(album_id) FROM albums));

-- Songs (16) — every row is a real file in ~/Music --------------
INSERT INTO songs (song_id, album_id, title, duration_seconds, track_number, explicit, play_count, file_path) VALUES
  ( 1,  1, 'Let You Down',                                                  283,  1, FALSE, 1_240_000, 'Cyberpunk Edgerunners — Ending Theme  Let You Down by Dawid Podsiadło  Netflix.mp3'),
  ( 2,  2, 'Welcome to Die (Scar Gate — MAP01)',                            149,  1, FALSE,    62_000, 'DOOM Legacy of Rust OST - Welcome to Die (Scar Gate - MAP01).mp3'),
  ( 3,  2, 'The Shores of Heaven (Text Screen & Sanguine Wastes — MAP02)', 249,  2, FALSE,    51_000, 'DOOM Legacy of Rust OST - The Shores of Heaven (Text Screen & Sanguine Wastes - MAP02).mp3'),
  ( 4,  2, 'Cliff Driver (Falsehood — MAP09)',                              217,  9, FALSE,    44_000, 'DOOM Legacy of Rust OST - Cliff Driver (Falsehood - MAP09).mp3'),
  ( 5,  3, 'At Doom''s Gate (E1M1)',                                        198,  1, FALSE,   810_000, 'Doom - At Doom''s Gate E1M1 remake by Andrew Hulshult.mp3'),
  ( 6,  3, 'Nobody Told Me About ID (Tower of Babel)',                      232,  2, FALSE,   305_000, 'Doom - Nobody Told Me About ID (Tower of Babel) remake by Andrew Hulshult.mp3'),
  ( 7,  4, 'The Only Thing They Fear Is You',                               413,  1, FALSE, 4_900_000, 'Doom Eternal OST - The Only Thing They Fear Is You (Mick Gordon) [Doom Eternal Theme].mp3'),
  ( 8,  5, 'Infernal Chasm',                                                403,  1, FALSE,    78_000, 'Infernal Chasm - DOOM The Dark Ages (Original Game Soundtrack) OFFICIAL.mp3'),
  ( 9,  6, 'Nu Tenta Evita',                                                206,  1, FALSE,   140_000, 'Irina Barros X Mr. Carly - Nu Tenta Evita (Official Video).mp3'),
  (10,  7, 'Rip & Tear',                                                    258,  2, TRUE,  3_600_000, 'Mick Gordon - 02. Rip & Tear.mp3'),
  (11,  7, 'BFG Division',                                                  507, 11, FALSE, 5_500_000, 'Mick Gordon - 11. BFG Division.mp3'),
  (12,  8, 'Por Enquanto',                                                  188,  1, FALSE,   720_000, 'Plutonio - Por Enquanto.mp3'),
  (13,  9, 'Game Over',                                                     231,  1, FALSE,    18_000, 'Royalty Free Heavy Metal Instrumental - Game Over.mp3'),
  (14, 10, 'Ma Meilleure Ennemie',                                          169,  1, FALSE, 6_200_000, 'Stromae, Pomme - “Ma Meilleure Ennemie” (from Arcane Season 2) [Official Music Video].mp3'),
  (15,  5, 'Unchained Predator (Reimagined)',                               375,  2, FALSE,    66_000, 'Unchained Predator (Reimagined) - DOOM The Dark Ages.mp3'),
  (16,  5, 'Unchained Predator',                                            345,  3, FALSE,    71_000, 'Unchained Predator - DOOM The Dark Ages (Original Game Soundtrack) OFFICIAL.mp3');
SELECT setval('songs_song_id_seq', (SELECT MAX(song_id) FROM songs));

-- Playlists curated around the real library --------------------
INSERT INTO playlists (playlist_id, user_id, name, is_public) VALUES
  ( 1, 1, 'DOOM Marathon',         TRUE),
  ( 2, 1, 'Mick Gordon Essentials',TRUE),
  ( 3, 2, 'Cyberpunk Vibes',       TRUE),
  ( 4, 3, 'Late Night Heavy',      FALSE),
  ( 5, 4, 'Family Roadtrip',       TRUE),
  ( 6, 5, 'Workout Fuel',          TRUE),
  ( 7, 6, 'Café Bossa',            TRUE),
  ( 8, 7, 'Animation Soundtracks', TRUE),
  ( 9, 8, 'Game OSTs',             TRUE),
  (10, 11,'Português',             TRUE),
  (11, 12,'Polski Pop',            TRUE),
  (12, 1, 'All Time Top',          TRUE);
SELECT setval('playlists_playlist_id_seq', (SELECT MAX(playlist_id) FROM playlists));

-- Playlist contents --------------------------------------------
INSERT INTO playlist_songs (playlist_id, song_id, position) VALUES
  -- DOOM Marathon: every DOOM track in chronological-ish order
  ( 1,  5, 1), ( 1,  6, 2), ( 1, 10, 3), ( 1, 11, 4),
  ( 1,  7, 5), ( 1,  8, 6), ( 1, 16, 7), ( 1, 15, 8),
  ( 1,  2, 9), ( 1,  3,10), ( 1,  4,11),
  -- Mick Gordon Essentials
  ( 2, 10, 1), ( 2, 11, 2), ( 2,  7, 3),
  -- Cyberpunk Vibes
  ( 3,  1, 1), ( 3, 14, 2),
  -- Late Night Heavy
  ( 4, 11, 1), ( 4,  7, 2), ( 4,  8, 3), ( 4, 13, 4),
  -- Family Roadtrip
  ( 5,  1, 1), ( 5, 14, 2), ( 5, 12, 3), ( 5,  9, 4),
  -- Workout Fuel
  ( 6, 10, 1), ( 6, 11, 2), ( 6,  7, 3), ( 6, 13, 4), ( 6,  5, 5),
  -- Café Bossa
  ( 7,  9, 1), ( 7, 12, 2),
  -- Animation Soundtracks
  ( 8,  1, 1), ( 8, 14, 2),
  -- Game OSTs
  ( 9,  5, 1), ( 9,  6, 2), ( 9, 10, 3), ( 9,  7, 4), ( 9,  8, 5),
  ( 9, 15, 6), ( 9, 16, 7), ( 9,  2, 8), ( 9,  3, 9), ( 9,  4,10),
  -- Português
  (10,  9, 1), (10, 12, 2),
  -- Polski Pop
  (11,  1, 1),
  -- All Time Top
  (12, 14, 1), (12, 11, 2), (12,  7, 3), (12, 10, 4), (12,  1, 5);

UPDATE playlists p
SET song_count = sub.cnt
FROM (
    SELECT playlist_id, COUNT(*) AS cnt
    FROM playlist_songs
    GROUP BY playlist_id
) sub
WHERE sub.playlist_id = p.playlist_id;

-- Play history --------------------------------------------------
-- A realistic, deterministic spread across the 12 users and 16 songs.
INSERT INTO play_history (user_id, song_id, played_at, seconds_listened, completed)
SELECT
    1 + (g % 12)                                             AS user_id,
    1 + (g * 7 % 16)                                         AS song_id,
    CURRENT_TIMESTAMP - ((g % 96) || ' hours')::INTERVAL     AS played_at,
    30 + (g * 13) % 200                                      AS seconds_listened,
    (g % 3 = 0)                                              AS completed
FROM generate_series(1, 200) AS g;

-- A few active sessions ----------------------------------------
INSERT INTO user_sessions (user_id, device) VALUES
  (1, 'web'), (1, 'mobile'), (3, 'desktop'),
  (4, 'mobile'), (6, 'web'), (11, 'mobile');
