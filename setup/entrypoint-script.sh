#!/bin/sh
set -e

echo "Generating seed data from ~/Music..."

if [ -d "/music" ]; then
    python3 /usr/local/bin/generate-seed-data.py > /docker-entrypoint-initdb.d/01-seed-data.sql 2>/dev/null || {
        echo "Warning: Could not generate seed data from /music"
        echo "Using static fallback data..."
        cat > /docker-entrypoint-initdb.d/01-seed-data.sql << 'EOFALLBACK'
-- Fallback seed data (no music files detected)
INSERT INTO users (username, email, country, subscription) VALUES
('alice', 'alice@example.com', 'US', 'premium'),
('bob', 'bob@example.com', 'UK', 'free'),
('charlie', 'charlie@example.com', 'CA', 'family');

INSERT INTO artists (name, genre, country, monthly_listeners) VALUES
('The Beatles', 'Rock', 'GB', 1000000),
('David Bowie', 'Rock', 'GB', 500000),
('Pink Floyd', 'Rock', 'GB', 800000);

INSERT INTO albums (artist_id, title, release_year) VALUES
(1, 'Abbey Road', 1969),
(2, 'Ziggy Stardust', 1972),
(3, 'The Wall', 1979);

INSERT INTO songs (album_id, title, duration_seconds, track_number, play_count, explicit, file_path) VALUES
(1, 'Come Together', 259, 1, 10000, FALSE, 'the-beatles-come-together.mp3'),
(1, 'Something', 183, 2, 8000, FALSE, 'the-beatles-something.mp3'),
(2, 'Starman', 258, 1, 12000, FALSE, 'david-bowie-starman.mp3'),
(3, 'In the Flesh', 113, 1, 5000, FALSE, 'pink-floyd-in-the-flesh.mp3');

INSERT INTO playlists (user_id, name, is_public) VALUES
(1, 'Classics', TRUE),
(2, 'Favorites', TRUE);

INSERT INTO playlist_songs (playlist_id, song_id, position) VALUES
(1, 1, 1),
(1, 3, 2),
(2, 2, 1),
(2, 4, 2);
EOFALLBACK
    }
else
    echo "Warning: /music volume not mounted. Music files will not be available."
    echo "Make sure ~/Music is mounted to /music in docker-compose.yml"
fi

echo "Seed data ready. Starting PostgreSQL..."
exec /usr/local/bin/docker-entrypoint.sh "$@"
