import pg from 'pg';

const { Pool } = pg;

export const pool = new Pool({
  host:     process.env.PGHOST     || 'db',
  port:     Number(process.env.PGPORT) || 5432,
  user:     process.env.PGUSER     || 'music',
  password: process.env.PGPASSWORD || 'music',
  database: process.env.PGDATABASE || 'music',
  max: 10,
  idleTimeoutMillis: 30_000,
});

export async function waitForDb(retries = 30, delayMs = 1000) {
  for (let i = 0; i < retries; i++) {
    try {
      await pool.query('SELECT 1');
      return;
    } catch (err) {
      console.log(`[db] not ready (${i + 1}/${retries}): ${err.code || err.message}`);
      await new Promise(r => setTimeout(r, delayMs));
    }
  }
  throw new Error('Database never became ready.');
}
