#!/usr/bin/env python3
import os
import sys
from pathlib import Path
from datetime import datetime, timedelta
import random

MUSIC_DIR = Path(os.environ.get("MUSIC_DIR", str(Path.home() / "Music")))
MIN_SONGS = 30

def scan_music_directory():
    """Scan ~/Music for MP3 files and organize by metadata."""
    if not MUSIC_DIR.exists():
        print(f"Error: {MUSIC_DIR} does not exist", file=sys.stderr)
        sys.exit(1)

    mp3_files = list(MUSIC_DIR.glob("**/*.mp3"))

    if len(mp3_files) < MIN_SONGS:
        print(f"Warning: Found only {len(mp3_files)} MP3 files in {MUSIC_DIR}", file=sys.stderr)
        print(f"         (minimum recommended: {MIN_SONGS})", file=sys.stderr)

    songs = []
    for mp3_file in sorted(mp3_files):
        rel_path = mp3_file.relative_to(MUSIC_DIR)
        stat = mp3_file.stat()
        duration = int(stat.st_size / 32000) if stat.st_size else 180
        duration = max(30, min(duration, 3599))

        parts = rel_path.stem.split(" - ")
        if len(parts) >= 3:
            artist = parts[0].strip()
            album = parts[1].strip()
            title = parts[2].strip()
        elif len(parts) == 2:
            artist = parts[0].strip()
            album = "Untitled Album"
            title = parts[1].strip()
        else:
            artist = "Unknown Artist"
            album = "Untitled Album"
            title = rel_path.stem

        songs.append({
            'title': title,
            'artist': artist,
            'album': album,
            'file_path': str(rel_path),
            'duration': duration,
            'track_number': len(songs) + 1,
        })

    return songs

def generate_sql(songs):
    """Generate SQL INSERT statements from scanned songs."""

    artists = {}
    albums = {}
    artist_id = 1
    album_id = 1

    sql_lines = []
    sql_lines.append("-- Auto-generated seed data from ~/Music")
    sql_lines.append(f"-- Scanned {len(songs)} songs on {datetime.now().isoformat()}")
    sql_lines.append("")

    sql_lines.append("-- Insert artists")
    for song in songs:
        key = song['artist'].lower()
        if key not in artists:
            genre = random.choice(['Rock', 'Pop', 'Hip-Hop', 'Jazz', 'Electronic', 'Classical', 'R&B', 'Country'])
            artists[key] = {
                'id': artist_id,
                'name': song['artist'],
                'genre': genre,
            }
            artist_id += 1

    for artist_data in sorted(artists.values(), key=lambda x: x['id']):
        sql_lines.append(
            f"INSERT INTO artists (name, genre, country, monthly_listeners) "
            f"VALUES ('{escape_sql(artist_data['name'])}', '{artist_data['genre']}', 'US', {random.randint(100, 100000)});"
        )

    sql_lines.append("")
    sql_lines.append("-- Insert albums")
    for song in songs:
        key = (song['artist'].lower(), song['album'].lower())
        if key not in albums:
            artist_data = artists[key[0]]
            albums[key] = {
                'id': album_id,
                'title': song['album'],
                'artist_id': artist_data['id'],
                'year': random.randint(2010, 2024),
            }
            album_id += 1

    for album_data in sorted(albums.values(), key=lambda x: x['id']):
        sql_lines.append(
            f"INSERT INTO albums (artist_id, title, release_year) "
            f"VALUES ({album_data['artist_id']}, '{escape_sql(album_data['title'])}', {album_data['year']});"
        )

    sql_lines.append("")
    sql_lines.append("-- Insert songs")
    for i, song in enumerate(songs):
        key = (song['artist'].lower(), song['album'].lower())
        album_data = albums[key]
        play_count = random.randint(0, 50000)
        explicit = 'TRUE' if random.random() < 0.1 else 'FALSE'

        sql_lines.append(
            f"INSERT INTO songs (album_id, title, duration_seconds, track_number, play_count, explicit, file_path) "
            f"VALUES ({album_data['id']}, '{escape_sql(song['title'])}', {song['duration']}, {song['track_number']}, "
            f"{play_count}, {explicit}, '{escape_sql(song['file_path'])}');"
        )

    sql_lines.append("")
    sql_lines.append("-- Insert sample users")
    sql_lines.append("INSERT INTO users (username, email, country, subscription) VALUES")
    users = [
        ('alice', 'alice@example.com', 'US', 'premium'),
        ('bob', 'bob@example.com', 'UK', 'free'),
        ('charlie', 'charlie@example.com', 'CA', 'family'),
        ('diana', 'diana@example.com', 'AU', 'premium'),
        ('eve', 'eve@example.com', 'DE', 'free'),
        ('frank', 'frank@example.com', 'FR', 'premium'),
        ('grace', 'grace@example.com', 'JP', 'family'),
        ('henry', 'henry@example.com', 'BR', 'free'),
    ]
    for i, (username, email, country, sub) in enumerate(users):
        comma = ',' if i < len(users) - 1 else ';'
        sql_lines.append(f"('{{username}}', '{email}', '{country}', '{sub}'){comma}".replace('{{username}}', username))

    sql_lines.append("")
    sql_lines.append("-- Insert sample playlists")
    sql_lines.append("INSERT INTO playlists (user_id, name, is_public) VALUES")
    playlists = [
        (1, 'Chill Vibes', True),
        (1, 'Workout Mix', False),
        (2, 'Favorites', True),
        (2, 'Discover', True),
        (3, 'Late Night', False),
        (4, 'Feel Good', True),
    ]
    for i, (user_id, name, is_public) in enumerate(playlists):
        comma = ',' if i < len(playlists) - 1 else ';'
        sql_lines.append(f"({user_id}, '{name}', {str(is_public).upper()}){comma}")

    sql_lines.append("")
    sql_lines.append("-- Insert songs into playlists")
    if songs:
        song_ids = list(range(1, len(songs) + 1))
        for playlist_id in range(1, 7):
            sample_songs = random.sample(song_ids, min(random.randint(3, 10), len(song_ids)))
            for pos, song_id in enumerate(sorted(sample_songs), 1):
                sql_lines.append(
                    f"INSERT INTO playlist_songs (playlist_id, song_id, position) "
                    f"VALUES ({playlist_id}, {song_id}, {pos});"
                )

    sql_lines.append("")
    sql_lines.append("-- Insert play history")
    if songs:
        song_ids = list(range(1, len(songs) + 1))
        now = datetime.now()
        for _ in range(min(50, len(songs) * 2)):
            user_id = random.randint(1, 8)
            song_id = random.choice(song_ids)
            days_ago = random.randint(0, 30)
            played_at = now - timedelta(days=days_ago, hours=random.randint(0, 23))
            seconds_listened = random.randint(10, 360)
            completed = 'TRUE' if random.random() < 0.6 else 'FALSE'
            sql_lines.append(
                f"INSERT INTO play_history (user_id, song_id, played_at, seconds_listened, completed) "
                f"VALUES ({user_id}, {song_id}, '{played_at.isoformat()}', {seconds_listened}, {completed});"
            )

    return '\n'.join(sql_lines)

def escape_sql(s):
    """Escape single quotes in SQL strings."""
    return s.replace("'", "''")

if __name__ == '__main__':
    print("Scanning music directory...", file=sys.stderr)
    songs = scan_music_directory()
    print(f"Found {len(songs)} songs", file=sys.stderr)

    sql = generate_sql(songs)
    print(sql)
