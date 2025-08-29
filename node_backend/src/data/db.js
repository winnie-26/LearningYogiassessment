const { Pool } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL;
let pool = null;

if (DATABASE_URL) {
  pool = new Pool({ connectionString: DATABASE_URL, ssl: { rejectUnauthorized: false } });
}

async function migrate() {
  if (!pool) return;
  // Users
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL
    );
  `);
  // Groups
  await pool.query(`
    CREATE TABLE IF NOT EXISTS groups (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL UNIQUE,
      type TEXT NOT NULL,
      max_members INTEGER NOT NULL,
      owner_id INTEGER NOT NULL REFERENCES users(id),
      encrypted_group_key TEXT,
      key_nonce TEXT,
      created_at TIMESTAMPTZ DEFAULT now(),
      deleted_at TIMESTAMPTZ
    );
  `);
  
  // First ensure all columns exist
  await pool.query(`
    ALTER TABLE groups 
      ADD COLUMN IF NOT EXISTS encrypted_group_key TEXT,
      ADD COLUMN IF NOT EXISTS key_nonce TEXT,
      ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now(),
      ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
  `);

  // Handle duplicate group names
  const dupCheck = await pool.query(`
    SELECT name, COUNT(*) as count 
    FROM groups 
    GROUP BY name 
    HAVING COUNT(*) > 1
    LIMIT 1
  `);

  if (dupCheck.rows.length > 0) {
    // Create a temporary table to store the new names
    await pool.query(`
      CREATE TEMP TABLE temp_group_names AS 
      SELECT 
        id, 
        name,
        ROW_NUMBER() OVER (PARTITION BY name ORDER BY id) as rn 
      FROM groups;
      
      -- Update duplicate names with a suffix
      UPDATE groups g
      SET name = g.name || '_' || t.rn
      FROM temp_group_names t
      WHERE g.id = t.id AND t.rn > 1;
      
      DROP TABLE temp_group_names;
    `);
  }

  // Now add the unique constraint if it doesn't exist
  await pool.query(`
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'groups_name_key' AND contype = 'u'
      ) THEN
        ALTER TABLE groups ADD CONSTRAINT groups_name_key UNIQUE (name);
      END IF;
    END
    $$;
  `);;
  // Group members
  await pool.query(`
    CREATE TABLE IF NOT EXISTS group_members (
      group_id INTEGER NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      is_admin BOOLEAN NOT NULL DEFAULT false,
      joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (group_id, user_id)
    );
  `);
  
  // Add any missing columns to group_members
  await pool.query(`
    ALTER TABLE group_members 
    ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS joined_at TIMESTAMPTZ NOT NULL DEFAULT now();
  `);
  // Messages
  await pool.query(`
    CREATE TABLE IF NOT EXISTS messages (
      id SERIAL PRIMARY KEY,
      group_id INTEGER NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      text TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);
  // Ensure columns exist in case of older schema
  await pool.query(`ALTER TABLE messages ADD COLUMN IF NOT EXISTS group_id INTEGER`);
  await pool.query(`ALTER TABLE messages ADD COLUMN IF NOT EXISTS user_id INTEGER`);
  await pool.query(`ALTER TABLE messages ADD COLUMN IF NOT EXISTS text TEXT`);
  await pool.query(`ALTER TABLE messages ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now()`);
  // If a legacy sender_id column exists and is NOT NULL, relax it and backfill user_id
  await pool.query(`ALTER TABLE messages ADD COLUMN IF NOT EXISTS sender_id INTEGER`);
  await pool.query(`
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'messages' AND column_name = 'sender_id'
      ) THEN
        BEGIN
          -- Drop NOT NULL if present (safe even if already nullable)
          EXECUTE 'ALTER TABLE messages ALTER COLUMN sender_id DROP NOT NULL';
        EXCEPTION WHEN undefined_column THEN
          -- ignore
          NULL;
        END;
      END IF;
    END
    $$;
  `);
  // Backfill user_id from sender_id where missing
  await pool.query(`UPDATE messages SET user_id = sender_id WHERE user_id IS NULL AND sender_id IS NOT NULL`);
  // Ensure groups has encrypted_group_key nullable for legacy schemas
  await pool.query(`ALTER TABLE groups ADD COLUMN IF NOT EXISTS encrypted_group_key TEXT`);
  await pool.query(`
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'groups' AND column_name = 'encrypted_group_key'
      ) THEN
        BEGIN
          EXECUTE 'ALTER TABLE groups ALTER COLUMN encrypted_group_key DROP NOT NULL';
        EXCEPTION WHEN undefined_column THEN NULL;
        END;
      END IF;
    END
    $$;
  `);
  // Join Requests
  await pool.query(`
    CREATE TABLE IF NOT EXISTS join_requests (
      id SERIAL PRIMARY KEY,
      group_id INTEGER NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','declined'))
    );
  `);
}

function isDbEnabled() { return !!pool; }
function getPool() { return pool; }

async function withTx(fn) {
  if (!pool) return fn(null);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (e) {
    try { await client.query('ROLLBACK'); } catch (_) {}
    throw e;
  } finally {
    client.release();
  }
}

module.exports = { isDbEnabled, getPool, migrate, withTx };
