import { MongoClient } from 'mongodb';

const MONGO_URI = process.env.MONGO_URI || 'mongodb://music:music@localhost:27017/music?authSource=admin';

let client = null;
let db = null;

export async function connectMongo(retries = 30, delayMs = 1000) {
  for (let i = 0; i < retries; i++) {
    try {
      client = new MongoClient(MONGO_URI);
      await client.connect();
      db = client.db('music');
      await db.command({ ping: 1 });
      console.log('[mongo] connected');
      return db;
    } catch (err) {
      console.log(`[mongo] not ready (${i + 1}/${retries}): ${err.message}`);
      await new Promise(r => setTimeout(r, delayMs));
    }
  }
  throw new Error('MongoDB never became ready.');
}

export function getDb() {
  if (!db) throw new Error('MongoDB not connected');
  return db;
}

export async function closeMongo() {
  if (client) await client.close();
}

export async function recordPlay(play) {
  const col = getDb().collection('plays');
  await col.insertOne({
    user_id: play.user_id,
    song_id: play.song_id,
    seconds_listened: play.seconds_listened,
    completed: play.completed,
    played_at: new Date(),
    username: play.username || null,
    song_title: play.song_title || null,
    artist_name: play.artist_name || null,
    duration_seconds: play.duration_seconds || null,
  });
}

export async function generateRecommendations(userId) {
  const db = getDb();
  const playsCol = db.collection('plays');
  const recsCol = db.collection('recommendations');

  const pipeline = [
    { $match: { user_id: userId } },
    { $group: { _id: '$artist_name', count: { $sum: 1 }, genres: { $addToSet: '$genre' } } },
    { $sort: { count: -1 } },
    { $limit: 5 },
  ];

  const topArtists = await playsCol.aggregate(pipeline).toArray();
  const favArtists = topArtists.map(a => a._id).filter(Boolean);

  const otherUsers = await playsCol.distinct('user_id', {
    user_id: { $ne: userId },
    artist_name: { $in: favArtists },
  });

  let recommended = [];
  if (otherUsers.length > 0) {
    const recsFromOthers = await playsCol.aggregate([
      { $match: { user_id: { $in: otherUsers }, song_id: { $nin: await playsCol.distinct('song_id', { user_id: userId }) } } },
      { $group: { _id: { song_id: '$song_id', title: '$song_title', artist: '$artist_name' }, score: { $sum: 1 } } },
      { $sort: { score: -1 } },
      { $limit: 10 },
    ]).toArray();

    recommended = recsFromOthers.map(r => ({
      song_id: r._id.song_id,
      title: r._id.title,
      artist: r._id.artist,
      score: r.score,
    }));
  }

  if (recommended.length < 5) {
    const topSongs = await playsCol.aggregate([
      { $match: { user_id: { $ne: userId } } },
      { $group: { _id: { song_id: '$song_id', title: '$song_title', artist: '$artist_name' }, plays: { $sum: 1 } } },
      { $sort: { plays: -1 } },
      { $limit: 10 },
    ]).toArray();

    for (const s of topSongs) {
      if (!recommended.find(r => r.song_id === s._id.song_id)) {
        recommended.push({
          song_id: s._id.song_id,
          title: s._id.title,
          artist: s._id.artist,
          score: s.plays * 0.5,
        });
      }
    }
  }

  recommended = recommended.slice(0, 10);

  await recsCol.updateOne(
    { user_id: userId },
    { $set: { user_id: userId, songs: recommended, generated_at: new Date() } },
    { upsert: true },
  );

  return recommended;
}

export async function getRecommendations(userId) {
  const doc = await getDb().collection('recommendations').findOne({ user_id: userId });
  return doc ? doc.songs : [];
}

export async function getRecentPlays(limit = 20) {
  return getDb().collection('plays')
    .find({})
    .sort({ played_at: -1 })
    .limit(limit)
    .toArray();
}

export async function getMongoStats() {
  const db = getDb();
  const playsCount = await db.collection('plays').countDocuments();
  const recsCount = await db.collection('recommendations').countDocuments();
  const latestPlay = await db.collection('plays').findOne({}, { sort: { played_at: -1 } });
  const topSongs = await db.collection('plays').aggregate([
    { $group: { _id: { song_id: '$song_id', title: '$song_title', artist: '$artist_name' }, plays: { $sum: 1 } } },
    { $sort: { plays: -1 } },
    { $limit: 5 },
  ]).toArray();

  return {
    collections: { plays: playsCount, recommendations: recsCount },
    latest_play: latestPlay ? { song_title: latestPlay.song_title, artist: latestPlay.artist_name, played_at: latestPlay.played_at } : null,
    top_played_songs: topSongs.map(s => ({
      song_id: s._id.song_id,
      title: s._id.title,
      artist: s._id.artist,
      plays: s.plays,
    })),
  };
}
