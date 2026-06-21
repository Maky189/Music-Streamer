# NoSQL Integration — MongoDB in the Music Streaming Platform

## Overview

This project integrates **MongoDB** (document NoSQL database) alongside **PostgreSQL**
(relational database) to demonstrate a hybrid architecture. Each database serves the
access patterns it is best suited for:

| Concern                | Database   | Why                                                         |
|------------------------|------------|-------------------------------------------------------------|
| Core business data     | PostgreSQL | ACID transactions, foreign keys, complex joins              |
| Play activity feed     | MongoDB    | Time-series, fast append, denormalized reads                |
| Song recommendations   | MongoDB    | Computed via aggregation, stored as documents               |
| Analytics / stats      | MongoDB    | Aggregation pipeline, real-time grouping                    |

## MongoDB Collections

### `plays` — Time-series Activity Log

Each play event is stored as a document with **denormalized** song and user data for fast reads:

```json
{
  "_id": ObjectId,
  "user_id": 1,
  "song_id": 7,
  "seconds_listened": 180,
  "completed": true,
  "played_at": ISODate,
  "username": "alice",
  "song_title": "The Only Thing They Fear Is You",
  "artist_name": "Mick Gordon",
  "duration_seconds": 413
}
```

**Why denormalize?** In a relational DB, reading a play activity feed requires joining
4+ tables (play_history -> songs -> albums -> artists + users). In MongoDB, a single
document has everything needed for display — no JOINs at read time.

### `recommendations` — Pre-computed Song Suggestions

Generated per-user via the aggregation pipeline and cached for fast retrieval:

```json
{
  "_id": ObjectId,
  "user_id": 1,
  "generated_at": ISODate,
  "songs": [
    { "song_id": 7, "title": "...", "artist": "Mick Gordon", "score": 0.95 },
    { "song_id": 11, "title": "...", "artist": "Mick Gordon", "score": 0.82 }
  ]
}
```

## Recommendation Algorithm

The recommendation engine (`backend/src/mongo.js`) works in three phases:

1. **Analyze user's listening history** — Group plays by artist, find top 5 most-listened
   artists via the aggregation pipeline (`$group` + `$sort` + `$limit`).

2. **Find similar users** — Query MongoDB for other users who also listen to those artists
   (`$in` filter + `$distinct`).

3. **Recommend unplayed songs** — Find songs that similar users listen to but the target
   user hasn't played, ranked by play count. If not enough recommendations are found,
   fall back to global top songs (minus already-played ones).

Results are cached in the `recommendations` collection (upsert pattern) so repeated reads
are fast without re-running the pipeline.

## API Endpoints

| Method | Path                                   | Purpose                              |
|--------|----------------------------------------|--------------------------------------|
| POST   | `/api/plays/mongo`                     | Write a play event to MongoDB only   |
| GET    | `/api/mongo/stats`                     | Collection stats + top played songs  |
| GET    | `/api/mongo/recent-plays?limit=N`      | Read recent activity (time-series)   |
| GET    | `/api/recommendations/:userId`         | Get cached recommendations for user  |
| POST   | `/api/recommendations/generate/:userId`| Generate new recommendations         |

## Why MongoDB Here Instead of PostgreSQL?

### For Activity Feeds (plays)
- **Write pattern**: Append-only, high volume. In MongoDB each play is a single `insertOne()`
  with no locks, no foreign key checks, no transaction overhead.
- **Read pattern**: "Show recent plays" needs the document and everything needed to display it
  in one place. Denormalization eliminates 3-4 JOINs per query.
- **Data shape**: The activity document has a fixed schema plus optional fields — MongoDB's
  flexible schema handles this naturally.

### For Recommendations
- **Aggregation pipeline**: MongoDB's `$match` → `$group` → `$sort` pipeline is a natural
  fit for the collaborative-filtering-style algorithm.
- **Document cache**: Pre-computed results stored as a single document per user.
- **Schema evolution**: Recommendation formats can change without migrations.

### Trade-offs
- **No cross-document transactions**: We accept that a play might be recorded in PostgreSQL
  but fail in MongoDB (and vice versa). The PostgreSQL write is the source of truth.
- **Denormalization cost**: Song metadata is duplicated across play documents. If a song
  title changes (rare), historical play documents keep the old name.
- **Eventual consistency**: The MongoDB activity feed may lag behind PostgreSQL by a few
  milliseconds.

## How to Connect

```bash
# MongoDB shell
docker compose exec mongo mongosh -u music -p music --authenticationDatabase admin music

# Query recent plays
db.plays.find().sort({played_at: -1}).limit(5).pretty()

# Check recommendations for user 1
db.recommendations.findOne({user_id: 1})

# Aggregation: top played songs
db.plays.aggregate([
  {$group: {_id: {song_id: "$song_id", title: "$song_title"}, plays: {$sum: 1}}},
  {$sort: {plays: -1}},
  {$limit: 5}
])
```

## Connection Details

- **Host**: `mongo` (Docker network, resolved by Docker DNS)
- **Port**: `27017`
- **Database**: `music`
- **Auth**: `music` / `music` (authentication database: `admin`)
- **URI**: `mongodb://music:music@mongo:27017/music?authSource=admin`
