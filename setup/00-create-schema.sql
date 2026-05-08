-- ============================================================
-- Music Streaming DB — Schema (PostgreSQL)
-- ============================================================
-- Drop in reverse-dependency order so re-runs are idempotent.
DROP TABLE IF EXISTS audit_log         CASCADE;
DROP TABLE IF EXISTS play_history      CASCADE;
DROP TABLE IF EXISTS user_sessions     CASCADE;
DROP TABLE IF EXISTS playlist_songs    CASCADE;
DROP TABLE IF EXISTS playlists         CASCADE;
DROP TABLE IF EXISTS songs             CASCADE;
DROP TABLE IF EXISTS albums            CASCADE;
DROP TABLE IF EXISTS artists           CASCADE;
DROP TABLE IF EXISTS users             CASCADE;

-- ------------------------------------------------------------
-- Core domain tables
-- ------------------------------------------------------------
CREATE TABLE users (
    user_id       SERIAL PRIMARY KEY,
    username      VARCHAR(50)  NOT NULL UNIQUE,
    email         VARCHAR(255) NOT NULL UNIQUE,
    country       VARCHAR(2)   NOT NULL DEFAULT 'US',
    subscription  VARCHAR(20)  NOT NULL DEFAULT 'free'
                                CHECK (subscription IN ('free','premium','family')),
    created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modified_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE artists (
    artist_id   SERIAL PRIMARY KEY,
    name        VARCHAR(200) NOT NULL,
    genre       VARCHAR(50)  NOT NULL,
    country     VARCHAR(2)   NOT NULL DEFAULT 'US',
    monthly_listeners BIGINT NOT NULL DEFAULT 0
                          CHECK (monthly_listeners >= 0),
    created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE albums (
    album_id     SERIAL PRIMARY KEY,
    artist_id    INT NOT NULL REFERENCES artists(artist_id) ON DELETE CASCADE,
    title        VARCHAR(255) NOT NULL,
    release_year INT          NOT NULL CHECK (release_year BETWEEN 1900 AND 2100),
    label        VARCHAR(100),
    created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE songs (
    song_id          SERIAL PRIMARY KEY,
    album_id         INT NOT NULL REFERENCES albums(album_id) ON DELETE CASCADE,
    title            VARCHAR(255) NOT NULL,
    duration_seconds INT          NOT NULL CHECK (duration_seconds > 0 AND duration_seconds < 3600),
    track_number     INT          NOT NULL CHECK (track_number > 0),
    play_count       BIGINT       NOT NULL DEFAULT 0 CHECK (play_count >= 0),
    explicit         BOOLEAN      NOT NULL DEFAULT FALSE,
    file_path        VARCHAR(500),  -- relative to the mounted /music volume
    created_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE playlists (
    playlist_id  SERIAL PRIMARY KEY,
    user_id      INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    name         VARCHAR(100) NOT NULL,
    is_public    BOOLEAN      NOT NULL DEFAULT TRUE,
    song_count   INT          NOT NULL DEFAULT 0 CHECK (song_count >= 0),
    created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modified_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE playlist_songs (
    playlist_id INT NOT NULL REFERENCES playlists(playlist_id) ON DELETE CASCADE,
    song_id     INT NOT NULL REFERENCES songs(song_id)         ON DELETE CASCADE,
    position    INT NOT NULL CHECK (position > 0),
    added_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (playlist_id, song_id)
);

-- ------------------------------------------------------------
-- Auxiliary tables for advanced practice
-- ------------------------------------------------------------
CREATE TABLE play_history (
    play_id     BIGSERIAL PRIMARY KEY,
    user_id     INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    song_id     INT NOT NULL REFERENCES songs(song_id) ON DELETE CASCADE,
    played_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    seconds_listened INT NOT NULL CHECK (seconds_listened >= 0),
    completed   BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE user_sessions (
    session_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    started_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device       VARCHAR(50) NOT NULL DEFAULT 'web',
    is_active    BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE audit_log (
    audit_id    BIGSERIAL PRIMARY KEY,
    table_name  VARCHAR(50) NOT NULL,
    operation   VARCHAR(10) NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE')),
    row_pk      VARCHAR(50) NOT NULL,
    actor       VARCHAR(50) NOT NULL DEFAULT CURRENT_USER,
    payload     JSONB,
    occurred_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------
-- Baseline indexes (the practice/indexes exercises add more)
-- ------------------------------------------------------------
CREATE INDEX idx_albums_artist        ON albums(artist_id);
CREATE INDEX idx_songs_album          ON songs(album_id);
CREATE INDEX idx_playlists_user       ON playlists(user_id);
CREATE INDEX idx_playlist_songs_song  ON playlist_songs(song_id);
CREATE INDEX idx_play_history_user    ON play_history(user_id);
CREATE INDEX idx_play_history_played  ON play_history(played_at DESC);
