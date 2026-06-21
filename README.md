# Music Streaming DB — Final Integrated Version

A Docker-powered full-stack music streaming platform integrating **PostgreSQL** (relational)
and **MongoDB** (NoSQL) with a live web console and audio playback from `~/Music`.

This project demonstrates:
- **Relational database design** with PostgreSQL (ACID transactions, foreign keys, triggers, indexes)
- **NoSQL integration** with MongoDB (document storage, aggregation, time-series activity feeds)
- **Hybrid architecture** — dual-writing to both databases for different access patterns
- **Real audio streaming** from your local music library

---

## Architecture

```
                                 ┌────────────────────────────────────┐
                                 │      Browser (localhost:8080)      │
                                 └────────────┬───────────────────────┘
                                              │ HTTP
                           ┌──────────────────▼───────────────────────┐
                           │   frontend (nginx + static HTML/JS/CSS)  │
                           │     • serves SPA                         │
                           │     • reverse-proxies /api/* → backend   │
                           └──────────────────┬───────────────────────┘
                                              │ /api/*
                           ┌──────────────────▼───────────────────────┐
                           │     backend (Node 20 + Express)          │
                           │     • REST API for all operations        │
                           │     • Dual-write plays to both databases │
                           │     • Audio streaming from /music        │
                           │     • MongoDB-driven recommendations     │
                           └─────┬──────────────────────────┬─────────┘
                                 │ SQL                      │ NoSQL
                           ┌─────▼──────────────┐    ┌──────▼──────────────┐
                           │  PostgreSQL 16     │    │  MongoDB 7          │
                           │  • users, artists  │    │  • plays (activity) │
                           │  • albums, songs   │    │  • recommendations  │
                           │  • playlists       │    │  • analytics        │
                           │  • play_history    │    └─────────────────────┘
                           │  • transactions    │
                           └─────┬──────────────┘
                                 │ read-only mount
                                 │ ${HOME}/Music → /music
                                 ▼
                         your ~/Music/*.mp3
```

The four services live in `docker-compose.yml`. Every service has a health check —
the backend waits for both databases before accepting connections.

---

## Data Distribution Strategy

| Data              | Primary Store | MongoDB | Rationale                                             |
|-------------------|---------------|---------|-------------------------------------------------------|
| Users             | PostgreSQL    | —       | Strong consistency, unique constraints                |
| Artists/Albums    | PostgreSQL    | —       | Join-heavy queries, referential integrity             |
| Songs/Playlists   | PostgreSQL    | —       | Transactional updates, complex queries                |
| Play history      | PostgreSQL    | ✓       | PG for transactional integrity, Mongo for analytics   |
| Recommendations   | —             | ✓       | Computed via aggregation, stored as documents         |
| Activity feed     | —             | ✓       | Time-series, fast reads with embedded denormalized data |

## Relational vs Non-Relational Databases

This project uses a **relational database** (PostgreSQL). Understanding the difference between
relational and non-relational databases is fundamental to database design.

### Relational Databases

A relational database organizes data into **tables** (also called relations) with **rows** and
**columns**. Data is structured into a predefined schema with:

- **Tables**: Represent entities (users, songs, playlists)
- **Rows**: Individual records
- **Columns**: Attributes with defined data types
- **Keys**: Primary keys uniquely identify rows; foreign keys link tables together
- **Relationships**: Data is normalized across tables to avoid redundancy

**Key characteristics:**
- Strong **ACID guarantees** (Atomicity, Consistency, Isolation, Durability)
- **Schema-enforced** — all columns and types are defined upfront
- **Joins** connect data across tables using foreign keys
- **SQL** provides a powerful, standardized query language
- **Transactions** ensure data integrity across multiple operations

Used in Financial systems, e-commerce, user management, anything where data integrity
and consistency are critical. In our music streaming app, we need transactions to ensure a
playlist edit and the song count stay in sync, and foreign keys to ensure a song can't be
added to a non-existent playlist.

### Non-Relational (NoSQL) Databases

Non-relational databases store data in flexible formats without a rigid schema:

- **Document databases** (MongoDB, Firebase): Store data as JSON-like documents
- **Key-value stores** (Redis, DynamoDB): Simple lookup by key
- **Graph databases** (Neo4j): Model relationships as edges and vertices
- **Time-series databases** (InfluxDB): Optimized for timestamped metrics

**Key characteristics:**
- **Schema-less** or flexible schemas — add fields without migration
- **Horizontal scaling** — easy to distribute across multiple servers
- **Fast writes** — optimized for high-volume inserts
- **Weaker consistency guarantees** — eventual consistency is common
- **No joins** — data is often denormalized (duplicated) for query speed

Used in Real-time analytics, session storage, caches, logs, content with varying
structure, or systems that prioritize speed over strict consistency.

### Why This Project Is Relational

The music streaming schema is **relational** because:

1. **Data integrity matters** — a song's duration can't be negative, a playlist can't reference
   a non-existent user, and atomicity ensures the song count always matches reality.
2. **Complex queries** — answering "Which genres does user 1 prefer?" requires joining users →
   play_history → songs → albums → artists. SQL makes this natural.
3. **Transactions** — adding a song to a playlist must atomically update both `playlist_songs`
   and the `song_count`. Either both succeed or both roll back.
4. **Consistency enforcement** — foreign keys prevent orphaned records; CHECK constraints
   enforce business rules (e.g., duration > 0).

A NoSQL approach (e.g., storing each playlist as a single JSON document with all songs embedded)
would be faster for single-playlist reads but would lose these guarantees — denormalizing the
song count means it can drift out of sync, adding a song to 100 playlists in a transaction
becomes fragile, and there's no automatic way to prevent invalid data.

---

## Architecture

```
                                ┌────────────────────────────┐
                                │   Browser (localhost:8080) │
                                └────────────┬───────────────┘
                                             │ HTTP
                          ┌──────────────────▼───────────────────┐
                          │  frontend  (nginx + static HTML/JS)  │
                          │   • serves index.html / app.js       │
                          │   • reverse-proxies /api/* → backend │
                          └──────────────────┬───────────────────┘
                                             │ HTTP, /api/*
                          ┌──────────────────▼───────────────────┐
                          │   backend  (Node 20 + Express + pg)  │
                          │   • REST endpoints over the DB       │
                          │   • transactions for write paths     │
                          │   • streams audio from /music        │
                          └─────┬──────────────────────────┬─────┘
                                │ SQL                      │ read-only file mount
                                │ (port 5432)              │ ${HOME}/Music → /music
                          ┌─────▼─────────────────┐        │
                          │  db (postgres:16)     │        │
                          │  • schema + seed      │        │
                          │  • init from setup/   │        │
                          │  • named volume       │        │
                          └───────────────────────┘        │
                                                           ▼
                                                   your ~/Music/*.mp3
```

The three services live in `docker-compose.yml`. The DB image is **built**, not pulled
plain, because we bake the init SQL into a custom image (avoids Docker Desktop / WSL
file-mount fragility).

## Quick start

```bash
docker compose up --build
```

The project **automatically scans `~/Music` for MP3 files** and populates the database with them. Every run uses your actual music library (or falls back to sample data if no MP3s are found).

| Service      | URL                                            | Purpose                                            |
|--------------|------------------------------------------------|----------------------------------------------------|
| Web console  | http://localhost:8080                          | Full UI: browse, search, play, recommendations    |
| API          | http://localhost:3001/api/health               | Health check (PG + Mongo status)                  |
| PostgreSQL   | `postgres://music:music@localhost:5432/music`  | psql / DBeaver / your client                      |
| MongoDB      | `mongodb://music:music@localhost:27017/music`  | mongosh / Compass / your client                   |

### How Music Detection Works

1. **Scan**: On startup, `setup/generate-seed-data.py` scans `~/Music` recursively for `.mp3` files
2. **Parse**: Filenames are parsed as `Artist - Album - Song` or `Artist - Song`
3. **Seed**: SQL INSERT statements are generated dynamically and loaded into Postgres
4. **Stream**: The backend serves actual audio from your library via `/api/songs/{id}/audio`

If no MP3s are found, the container uses fallback sample data so the UI still works.

### Customize Music Organization

The script expects MP3s to follow this naming convention:
```
~/Music/
├── Artist Name/
│   ├── Album Name/
│   │   ├── 01 - Song Title.mp3
│   │   ├── 02 - Another Song.mp3
```

Or flat:
```
~/Music/
├── Artist - Album - Song 1.mp3
├── Artist - Album - Song 2.mp3
```

### Bring it down (and wipe data)

```bash
docker compose down -v
```

### Connect to databases

```bash
docker compose exec db psql -U music -d music
docker compose exec mongo mongosh -u music -p music --authenticationDatabase admin music
```

## Database schema

Nine tables, 8 of them part of the core domain plus 1 audit table. Everything is
PostgreSQL 16. The full DDL lives in `setup/00-create-schema.sql`. Seed data is
generated dynamically from `~/Music` via `setup/generate-seed-data.py`.

### Entity-relationship overview

```
   artists ──< albums ──< songs ──< playlist_songs >── playlists >── users
                                       ▲                              │
                                       │                              │
                                  play_history ───────────────────────┤
                                                                      │
                                                            user_sessions
                                                                      │
                                            (every write target) ──> audit_log
```

- `artists` 1 — N `albums` 1 — N `songs`
- `playlist_songs` is the **N — N junction** between `playlists` and `songs`
- `playlists` belongs to a `user`; `play_history` and `user_sessions` belong to a `user`
- `audit_log` is the universal sink for triggers (and is keyed by `(table_name, row_pk)`)

### Table reference

#### `users`
| column        | type           | notes                                                         |
|---------------|----------------|---------------------------------------------------------------|
| user_id       | SERIAL PK      | autoincrement                                                 |
| username      | VARCHAR(50)    | UNIQUE, NOT NULL                                              |
| email         | VARCHAR(255)   | UNIQUE, NOT NULL                                              |
| country       | VARCHAR(2)     | ISO-2 country code, default `'US'`                            |
| subscription  | VARCHAR(20)    | CHECK in `('free','premium','family')`, default `'free'`      |
| created_at    | TIMESTAMP      | default `NOW()`                                               |
| modified_at   | TIMESTAMP      | default `NOW()` — meant to be auto-updated by a trigger       |

#### `artists`
| column            | type         | notes                                  |
|-------------------|--------------|----------------------------------------|
| artist_id         | SERIAL PK    |                                        |
| name              | VARCHAR(200) | NOT NULL                               |
| genre             | VARCHAR(50)  | NOT NULL                               |
| country           | VARCHAR(2)   | default `'US'`                         |
| monthly_listeners | BIGINT       | CHECK ≥ 0, default 0                   |
| created_at        | TIMESTAMP    | default `NOW()`                        |

#### `albums`
| column        | type         | notes                                                  |
|---------------|--------------|--------------------------------------------------------|
| album_id      | SERIAL PK    |                                                        |
| artist_id     | INT          | **FK → artists**, ON DELETE CASCADE                    |
| title         | VARCHAR(255) | NOT NULL                                               |
| release_year  | INT          | CHECK 1900..2100, NOT NULL                             |
| label         | VARCHAR(100) | NULLable                                               |
| created_at    | TIMESTAMP    | default `NOW()`                                        |

#### `songs`
| column            | type         | notes                                                       |
|-------------------|--------------|-------------------------------------------------------------|
| song_id           | SERIAL PK    |                                                             |
| album_id          | INT          | **FK → albums**, ON DELETE CASCADE                          |
| title             | VARCHAR(255) | NOT NULL                                                    |
| duration_seconds  | INT          | CHECK > 0 AND < 3600                                        |
| track_number      | INT          | CHECK > 0                                                   |
| play_count        | BIGINT       | CHECK ≥ 0, default 0                                        |
| explicit          | BOOLEAN      | default FALSE                                               |
| file_path         | VARCHAR(500) | path **relative to** `/music` mount; powers audio streaming |
| created_at        | TIMESTAMP    | default `NOW()`                                             |

#### `playlists`
| column        | type         | notes                                                    |
|---------------|--------------|----------------------------------------------------------|
| playlist_id   | SERIAL PK    |                                                          |
| user_id       | INT          | **FK → users**, ON DELETE CASCADE                        |
| name          | VARCHAR(100) | NOT NULL                                                 |
| is_public     | BOOLEAN      | default TRUE                                             |
| song_count    | INT          | CHECK ≥ 0, default 0 — **denormalised count**           |
| created_at    | TIMESTAMP    | default `NOW()`                                          |
| modified_at   | TIMESTAMP    | default `NOW()`                                          |

> `song_count` is intentionally redundant — keeping it correct is one of the practice
> scenarios. You'll explore both the procedural (transaction in code) and declarative
> (trigger) approach.

#### `playlist_songs` — the M:N junction
| column        | type      | notes                                                      |
|---------------|-----------|------------------------------------------------------------|
| playlist_id   | INT       | **FK → playlists**, ON DELETE CASCADE                      |
| song_id       | INT       | **FK → songs**, ON DELETE CASCADE                          |
| position      | INT       | CHECK > 0 — 1-based ordering inside the playlist           |
| added_at      | TIMESTAMP | default `NOW()`                                            |
|               |           | **PRIMARY KEY (playlist_id, song_id)** — no dupes per list |

#### `play_history`
| column            | type      | notes                                                        |
|-------------------|-----------|--------------------------------------------------------------|
| play_id           | BIGSERIAL PK | playback events can be very high volume                   |
| user_id           | INT       | **FK → users**, ON DELETE CASCADE                            |
| song_id           | INT       | **FK → songs**, ON DELETE CASCADE                            |
| played_at         | TIMESTAMP | default `NOW()`                                              |
| seconds_listened  | INT       | CHECK ≥ 0                                                    |
| completed         | BOOLEAN   | default FALSE — true if the user finished the song           |

#### `user_sessions`
| column        | type        | notes                                                      |
|---------------|-------------|------------------------------------------------------------|
| session_id    | UUID PK     | default `gen_random_uuid()`                                |
| user_id       | INT         | **FK → users**, ON DELETE CASCADE                          |
| started_at    | TIMESTAMP   | default `NOW()`                                            |
| last_seen_at  | TIMESTAMP   | default `NOW()`                                            |
| device        | VARCHAR(50) | default `'web'`                                            |
| is_active     | BOOLEAN     | default TRUE                                               |

#### `audit_log`
| column      | type         | notes                                                         |
|-------------|--------------|---------------------------------------------------------------|
| audit_id    | BIGSERIAL PK |                                                               |
| table_name  | VARCHAR(50)  | which table the event came from                               |
| operation   | VARCHAR(10)  | CHECK in `('INSERT','UPDATE','DELETE')`                       |
| row_pk      | VARCHAR(50)  | text representation of the affected row's PK                  |
| actor       | VARCHAR(50)  | default `CURRENT_USER`                                        |
| payload     | JSONB        | usually `{old, new}` snapshots from a trigger                 |
| occurred_at | TIMESTAMP    | default `NOW()`                                               |

### Indexes shipped in the schema

```sql
idx_albums_artist        (albums.artist_id)
idx_songs_album          (songs.album_id)
idx_playlists_user       (playlists.user_id)
idx_playlist_songs_song  (playlist_songs.song_id)
idx_play_history_user    (play_history.user_id)
idx_play_history_played  (play_history.played_at DESC)
```

The `practice/indexes/` exercises walk you through profiling queries with `EXPLAIN
ANALYZE`, deciding when to add more (composite, partial, expression, GIN trigram,
`INCLUDE`-covering), and how to prove an index actually helps.

## Backend API

Express on port 3001, served via the nginx reverse proxy at `/api/*`.

### PostgreSQL Endpoints

| Method | Path                                | Purpose                                                                      |
|--------|-------------------------------------|------------------------------------------------------------------------------|
| GET    | `/api/health`                       | Health check; returns `{ ok, pg: {...}, mongo: {...} }`                      |
| GET    | `/api/stats`                        | Row counts per table — drives the dashboard tiles                            |
| GET    | `/api/users`                        | All users                                                                    |
| POST   | `/api/users`                        | Create user (`{ username, email, country, subscription }`)                   |
| GET    | `/api/artists`                      | Artists with total play counts (aggregate across albums/songs)               |
| GET    | `/api/songs/top?limit=N`            | Top-N by play_count                                                          |
| GET    | `/api/songs/search?q=...`           | ILIKE search across song titles AND artist names                             |
| GET    | `/api/songs/:id/audio`              | **Streams the mp3** from `/music/<file_path>` (with traversal guard)         |
| GET    | `/api/playlists`                    | All playlists with owner username                                            |
| GET    | `/api/playlists/:id`                | Playlist metadata + ordered song list                                        |
| POST   | `/api/playlists`                    | Create playlist                                                              |
| POST   | `/api/playlists/:id/songs`          | **Transactional**: lock parent row, append song, bump `song_count`           |
| POST   | `/api/plays`                        | **Transactional**: insert into `play_history`; if completed, bump play_count |

### MongoDB Endpoints (NoSQL Feature)

| Method | Path                                   | Purpose                                                    |
|--------|----------------------------------------|------------------------------------------------------------|
| POST   | `/api/plays/mongo`                     | Record a play event directly in MongoDB                    |
| GET    | `/api/mongo/stats`                     | MongoDB collection stats + top played songs                |
| GET    | `/api/mongo/recent-plays?limit=N`      | Recent play activity feed (time-series from MongoDB)       |
| GET    | `/api/recommendations/:userId`         | Get song recommendations for a user                        |
| POST   | `/api/recommendations/generate/:userId`| Generate/refresh recommendations using aggregation pipeline |

The two `POST` endpoints that mutate multiple tables (`/playlists/:id/songs`,
`/plays`) wrap their work in `BEGIN / COMMIT` and use `SELECT ... FOR UPDATE` for
concurrent-safe counter maintenance — a working illustration of what
`docs/02-transactions.md` and `docs/03-isolation-levels.md` describe.

## Frontend console

A single-page, framework-free HTML/CSS/JS app served by nginx (`frontend/`):

- **Dashboard tiles**: row counts per PostgreSQL table, refreshed on every action.
- **Recommendations engine**: Get NoSQL-powered song recommendations per user; generate/refresh with
  a single click (results are cached in MongoDB).
- **Top songs & top artists**: by aggregate play counts (PostgreSQL queries).
- **Search**: debounced ILIKE search across song titles and artist names.
- **Playlist browser**: pick → load → see ordered songs → play any track (transactional add).
- **Log plays**: three modes — PostgreSQL only, MongoDB only, or dual-write both.
- **Activity feed**: real-time recent plays streamed from MongoDB (time-series).
- **MongoDB stats**: collection counts, top played songs, latest play.
- **Dual database health indicators**: PostgreSQL and MongoDB status displayed in the header.
- **Sticky audio player**: streams mp3 from `~/Music` via the backend.

Whenever you do anything in the UI, the dashboard tiles re-fetch — you can watch both
databases react in real time.

## Practice exercises

All practice files are **TODO stubs** — empty templates with a clear objective and hints,
but no canonical solution. Six categories, 24 exercises:

```
practice/
├── transactions/   # 4 — BEGIN / COMMIT / ROLLBACK, savepoints, isolation
├── procedures/     # 4 — IN/OUT/INOUT params, error handling, composition
├── cursors/        # 4 — explicit DECLARE/OPEN/FETCH and FOR-IN shortcuts
├── triggers/       # 4 — audit log, validation, derived state, auto-timestamps
├── indexes/        # 4 — profiling, composite/partial/expression, finding dead indexes
└── advanced/       # 4 — concurrency bugs, deadlock, savepoints, SERIALIZABLE
```

Recommended order: **transactions → procedures → cursors → triggers → indexes → advanced**.
Each builds on the last. Read the matching `docs/` page first, then write the SQL.

## Query exercises & the auto-grader

Separately, `practice/queries/` contains **15 query-design exercises** (joins, chained
selections, aggregates, subqueries, window functions) with a self-grading script.

```bash
# Make sure the stack is up first
docker compose up -d

python3 practice/queries/check.py            # check all 15
python3 practice/queries/check.py 03 12 14   # check specific ones
```

Outcomes per exercise:

- **`:)`** — your result matches the reference (set-equal or order-equal as the prompt demands).
- **`:|`** — file is still all comments (not attempted).
- **`:(`** — fails. The grader prints:
  - row-count mismatch (if any),
  - the first row that differs (yours vs expected),
  - up to 3 missing or extra rows,
  - a hint when *only the ORDER BY* is wrong.

Difficulty ramp:

| #     | Topic                                  | Concept                          |
|-------|----------------------------------------|----------------------------------|
| 01-05 | List/join basics                       | 3-table JOIN, WHERE, GROUP BY    |
| 06-08 | Aggregates with HAVING, anti-joins     | LEFT JOIN ... IS NULL, COUNT     |
| 09-11 | Cross-table totals                     | SUM, top-N by group              |
| 12-13 | Window functions                       | ROW_NUMBER, SUM OVER             |
| 14    | Self-join                              | pair-finding via play_history    |
| 15    | Scalar subquery in HAVING              | comparison to global aggregate   |

Zero pip installs — the grader just shells out to `docker compose exec db psql`.

## Project layout

```
.
├── README.md                  # this file (full documentation)
├── docker-compose.yml         # 4-service stack (pg + mongo + backend + frontend)
├── docs/                      # 8 educational markdown files (SQL concepts)
│   └── 01-acid-properties.md  ...
├── setup/
│   ├── Dockerfile             # postgres:16 + baked-in init SQL
│   ├── 00-create-schema.sql   # CREATE TABLE / FK / CHECK / INDEX
│   ├── 01-seed-data.sql       # real catalog from ~/Music + users/playlists/plays
│   └── test-setup.sql         # smoke queries
├── practice/
│   ├── transactions/  ·  procedures/  ·  cursors/
│   ├── triggers/      ·  indexes/     ·  advanced/
│   └── queries/               # 15 graded query exercises + check.py
├── backend/
│   ├── Dockerfile             # node:20-alpine
│   ├── package.json           # express, pg, mongodb, cors
│   └── src/
│       ├── db.js              # pg.Pool + retry-until-ready
│       ├── mongo.js           # MongoDB client + recommendations + activity
│       └── server.js          # all REST routes, dual-write, audio streaming
├── frontend/
│   ├── Dockerfile             # nginx:1.27-alpine
│   ├── nginx.conf             # static files + /api reverse proxy
│   ├── index.html             # full UI with recommendations, activity, dual-write
│   ├── style.css              # dark theme, responsive grid, mongo/pg tags
│   └── app.js                 # all frontend logic + MongoDB integration
└── solutions/                 # intentionally empty — you fill these in
```
