const { Pool } = require('pg');
const path = require('path');
const fs = require('fs');
require('dotenv').config();

async function rollbackMigration() {
  const pool = new Pool({
    user: process.env.DB_USER || 'postgres',
    host: process.env.DB_HOST || 'localhost',
    database: process.env.DB_NAME || 'chat_app',
    password: process.env.DB_PASSWORD || 'postgres',
    port: process.env.DB_PORT || 5432,
  });

  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');
    
    console.log('Rolling back migration: 0002_add_group_invites_table');
    const rollbackSQL = fs.readFileSync(
      path.join(__dirname, '../migrations/0002_add_group_invites_table.down.sql'), 
      'utf8'
    );
    
    await client.query(rollbackSQL);
    await client.query('COMMIT');
    console.log('Rollback completed successfully');
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Rollback failed:', error);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

rollbackMigration().catch(console.error);
