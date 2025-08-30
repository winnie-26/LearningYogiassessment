const { Pool } = require('pg');
const path = require('path');
const fs = require('fs');
require('dotenv').config();

async function runMigration() {
  if (!process.env.DATABASE_URL) {
    throw new Error('DATABASE_URL is not set in environment variables');
  }
  
  const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.DATABASE_URL.includes('sslmode=require') 
      ? { rejectUnauthorized: false } 
      : false
  });

  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');
    
    console.log('Running migration: 0002_add_group_invites_table');
    const migrationSQL = fs.readFileSync(
      path.join(__dirname, '../migrations/0002_add_group_invites_table.up.sql'), 
      'utf8'
    );
    
    await client.query(migrationSQL);
    await client.query('COMMIT');
    console.log('Migration completed successfully');
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Migration failed:', error);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

runMigration().catch(console.error);
