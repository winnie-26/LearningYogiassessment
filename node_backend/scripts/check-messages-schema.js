const { Pool } = require('pg');
require('dotenv').config();

async function checkSchema() {
  const pool = new Pool({ 
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false }
  });

  try {
    // Check messages table columns
    const res = await pool.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns
      WHERE table_name = 'messages';
    `);
    
    console.log('Messages table columns:');
    console.table(res.rows);
    
    // Check sample data
    const sample = await pool.query('SELECT * FROM messages LIMIT 1');
    console.log('\nSample message row:');
    console.log(sample.rows[0]);
    
  } catch (error) {
    console.error('Error checking schema:', error);
  } finally {
    await pool.end();
  }
}

checkSchema();
