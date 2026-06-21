import express from 'express';
import cors from 'cors';
import path from 'node:path';
import fs from 'node:fs';
import { pool, waitForDb } from './db.js';
import { connectMongo, getMongoStats, getRecentPlays, recordPlay, getRecommendations, generateRecommendations } from './mongo.js';

const MUSIC_DIR = process.env.MUSIC_DIR || '/music';

const app = express();
app.use(cors());
app.use(express.json());

app.get('/api/health', async (_req, res) => {
  let pgOk = false, pgTime = null, mongoOk = false;
  try {
    const r = await pool.query('SELECT NOW() AS now');
    pgOk = true;
    pgTime = r.rows[0].now;
  } catch (e) { /* pg down */ }
  try {
    await getMongoStats();
    mongoOk = true;
  } catch (e) { /* mongo down */ }
  const ok = pgOk && mongoOk;
  res.status(ok ? 200 : 500).json({ ok, pg: { ok: pgOk, time: pgTime }, mongo: { ok: mongoOk } });
});

app.get('/api/stats', async (_req, res, next) => {
  try {
    const tables = ['users','artists','albums','songs','playlists','playlist_songs','play_history'];
    const counts = {};
    for (const t of tables) {
      const r = await pool.query(`SELECT COUNT(*)::int AS c FROM ${t}`);
      counts[t] = r.rows[0].c;
    }
    res.json(counts);
  } catch (e) { next(e); }
});

app.get('/api/users', async (_req, res, next) => {
  try {
    const r = await pool.query(
      `SELECT user_id, username, email, country, subscription, created_at
         FROM users ORDER BY user_id`);
    res.json(r.rows);
  } catch (e) { next(e); }
});

app.post('/api/users', async (req, res, next) => {
  const { username, email, country = 'US', subscription = 'free' } = req.body || {};
  if (!username || !email) return res.status(400).json({ error: 'username and email required' });
  try {
    const r = await pool.query(
      `INSERT INTO users (username, email, country, subscription)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [username, email, country, subscription]);
    res.status(201).json(r.rows[0]);
  } catch (e) { next(e); }
});

app.get('/api/artists', async (_req, res, next) => {
  try {
    const r = await pool.query(
      `SELECT ar.artist_id, ar.name, ar.genre, ar.country, ar.monthly_listeners,
              COALESCE(SUM(s.play_count), 0)::bigint AS total_plays
         FROM artists ar
         LEFT JOIN albums al ON al.artist_id = ar.artist_id
         LEFT JOIN songs  s  ON s.album_id   = al.album_id
         GROUP BY ar.artist_id
         ORDER BY total_plays DESC`);
    res.json(r.rows);
  } catch (e) { next(e); }
});

app.get('/api/songs/top', async (req, res, next) => {
  const limit = Math.min(Number(req.query.limit) || 20, 100);
  try {
    const r = await pool.query(
      `SELECT s.song_id, s.title, s.duration_seconds, s.play_count,
              al.title AS album, ar.name AS artist
         FROM songs s
         JOIN albums  al ON al.album_id  = s.album_id
         JOIN artists ar ON ar.artist_id = al.artist_id
         ORDER BY s.play_count DESC
         LIMIT $1`, [limit]);
    res.json(r.rows);
  } catch (e) { next(e); }
});

app.get('/api/songs/search', async (req, res, next) => {
  const q = String(req.query.q || '').trim();
  if (!q) return res.json([]);
  try {
    const r = await pool.query(
      `SELECT s.song_id, s.title, s.duration_seconds, ar.name AS artist
         FROM songs s
         JOIN albums  al ON al.album_id  = s.album_id
         JOIN artists ar ON ar.artist_id = al.artist_id
        WHERE s.title ILIKE '%' || $1 || '%'
           OR ar.name ILIKE '%' || $1 || '%'
        ORDER BY s.play_count DESC
        LIMIT 50`, [q]);
    res.json(r.rows);
  } catch (e) { next(e); }
});

app.get('/api/songs/:id/audio', async (req, res, next) => {
  try {
    const r = await pool.query(
      `SELECT file_path FROM songs WHERE song_id = $1`, [req.params.id]);
    const fp = r.rows[0]?.file_path;
    if (!fp) return res.status(404).json({ error: 'no audio for this song' });

    const resolved = path.resolve(MUSIC_DIR, fp);
    if (!resolved.startsWith(path.resolve(MUSIC_DIR) + path.sep)) {
      return res.status(400).json({ error: 'invalid path' });
    }
    if (!fs.existsSync(resolved)) {
      return res.status(404).json({ error: 'audio file not found on disk', file_path: fp });
    }
    res.sendFile(resolved, { headers: { 'Content-Type': 'audio/mpeg' } });
  } catch (e) { next(e); }
});

app.get('/api/playlists', async (_req, res, next) => {
  try {
    const r = await pool.query(
      `SELECT p.playlist_id, p.name, p.is_public, p.song_count, p.modified_at,
              u.username AS owner
         FROM playlists p
         JOIN users u ON u.user_id = p.user_id
         ORDER BY p.modified_at DESC`);
    res.json(r.rows);
  } catch (e) { next(e); }
});

app.get('/api/playlists/:id', async (req, res, next) => {
  try {
    const meta = await pool.query(
      `SELECT p.*, u.username AS owner
         FROM playlists p JOIN users u USING (user_id)
        WHERE p.playlist_id = $1`, [req.params.id]);
    if (!meta.rows[0]) return res.status(404).json({ error: 'not found' });
    const songs = await pool.query(
      `SELECT ps.position, s.song_id, s.title, s.duration_seconds, ar.name AS artist
         FROM playlist_songs ps
         JOIN songs   s  ON s.song_id    = ps.song_id
         JOIN albums  al ON al.album_id  = s.album_id
         JOIN artists ar ON ar.artist_id = al.artist_id
        WHERE ps.playlist_id = $1
        ORDER BY ps.position`, [req.params.id]);
    res.json({ ...meta.rows[0], songs: songs.rows });
  } catch (e) { next(e); }
});

app.post('/api/playlists', async (req, res, next) => {
  const { user_id, name, is_public = true } = req.body || {};
  if (!user_id || !name) return res.status(400).json({ error: 'user_id and name required' });
  try {
    const r = await pool.query(
      `INSERT INTO playlists (user_id, name, is_public)
       VALUES ($1, $2, $3) RETURNING *`, [user_id, name, is_public]);
    res.status(201).json(r.rows[0]);
  } catch (e) { next(e); }
});

app.post('/api/playlists/:id/songs', async (req, res, next) => {
  const playlistId = Number(req.params.id);
  const songId = Number(req.body?.song_id);
  if (!playlistId || !songId) return res.status(400).json({ error: 'song_id required' });
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const lockRes = await client.query(
      `SELECT song_count FROM playlists WHERE playlist_id = $1 FOR UPDATE`, [playlistId]);
    if (!lockRes.rows[0]) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'playlist not found' });
    }
    const posRes = await client.query(
      `SELECT COALESCE(MAX(position), 0) + 1 AS next FROM playlist_songs WHERE playlist_id = $1`,
      [playlistId]);
    await client.query(
      `INSERT INTO playlist_songs (playlist_id, song_id, position) VALUES ($1, $2, $3)`,
      [playlistId, songId, posRes.rows[0].next]);
    await client.query(
      `UPDATE playlists SET song_count = song_count + 1, modified_at = NOW()
        WHERE playlist_id = $1`, [playlistId]);
    await client.query('COMMIT');
    res.status(201).json({ playlist_id: playlistId, song_id: songId, position: posRes.rows[0].next });
  } catch (e) {
    await client.query('ROLLBACK').catch(() => {});
    if (e.code === '23505') return res.status(409).json({ error: 'song already in playlist' });
    next(e);
  } finally {
    client.release();
  }
});

app.post('/api/plays', async (req, res, next) => {
  const { user_id, song_id, seconds_listened, completed = false } = req.body || {};
  if (!user_id || !song_id || seconds_listened == null)
    return res.status(400).json({ error: 'user_id, song_id, seconds_listened required' });
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const r = await client.query(
      `INSERT INTO play_history (user_id, song_id, seconds_listened, completed)
       VALUES ($1, $2, $3, $4) RETURNING play_id, played_at`,
      [user_id, song_id, seconds_listened, completed]);
    if (completed) {
      await client.query(
        `UPDATE songs SET play_count = play_count + 1 WHERE song_id = $1`, [song_id]);
    }
    await client.query('COMMIT');
    res.status(201).json(r.rows[0]);
  } catch (e) {
    await client.query('ROLLBACK').catch(() => {});
    next(e);
  } finally {
    client.release();
  }
});

app.post('/api/plays/mongo', async (req, res, next) => {
  const { user_id, song_id, seconds_listened, completed = false } = req.body || {};
  if (!user_id || !song_id || seconds_listened == null)
    return res.status(400).json({ error: 'user_id, song_id, seconds_listened required' });
  try {
    const songInfo = await pool.query(
      `SELECT s.title AS song_title, s.duration_seconds, ar.name AS artist_name
         FROM songs s JOIN albums al ON al.album_id = s.album_id
         JOIN artists ar ON ar.artist_id = al.artist_id
        WHERE s.song_id = $1`, [song_id]);
    const userInfo = await pool.query(
      `SELECT username FROM users WHERE user_id = $1`, [user_id]);
    if (!songInfo.rows[0]) return res.status(404).json({ error: 'song not found' });
    await recordPlay({
      user_id,
      song_id,
      seconds_listened,
      completed,
      username: userInfo.rows[0]?.username || 'unknown',
      song_title: songInfo.rows[0]?.song_title,
      artist_name: songInfo.rows[0]?.artist_name,
      duration_seconds: songInfo.rows[0]?.duration_seconds,
    });
    res.status(201).json({ ok: true, stored: 'mongodb' });
  } catch (e) { next(e); }
});

app.get('/api/mongo/stats', async (_req, res, next) => {
  try {
    const stats = await getMongoStats();
    res.json(stats);
  } catch (e) { next(e); }
});

app.get('/api/mongo/recent-plays', async (req, res, next) => {
  const limit = Math.min(Number(req.query.limit) || 20, 100);
  try {
    const plays = await getRecentPlays(limit);
    res.json(plays);
  } catch (e) { next(e); }
});

app.get('/api/recommendations/:userId', async (req, res, next) => {
  const userId = Number(req.params.userId);
  if (!userId) return res.status(400).json({ error: 'userId required' });
  try {
    let recs = await getRecommendations(userId);
    if (recs.length === 0) {
      recs = await generateRecommendations(userId);
    }
    res.json(recs);
  } catch (e) { next(e); }
});

app.post('/api/recommendations/generate/:userId', async (req, res, next) => {
  const userId = Number(req.params.userId);
  if (!userId) return res.status(400).json({ error: 'userId required' });
  try {
    const recs = await generateRecommendations(userId);
    res.json(recs);
  } catch (e) { next(e); }
});

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: err.message, code: err.code });
});

const PORT = Number(process.env.PORT) || 3001;
Promise.all([waitForDb(), connectMongo()])
  .then(() => app.listen(PORT, () => console.log(`API on :${PORT}`)))
  .catch(err => { console.error(err); process.exit(1); });
