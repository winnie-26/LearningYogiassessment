const { Pool } = require('pg');
require('dotenv').config();

async function testDb() {
  const pool = new Pool({ 
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false }
  });

  try {
    console.log('Testing database connection...');
    const { rows } = await pool.query('SELECT NOW()');
    console.log('Database connection successful. Current time:', rows[0].now);
    
    // Test messages table query
    console.log('\nTesting messages table query...');
    const messages = await pool.query('SELECT * FROM messages LIMIT 1');
    console.log('Messages table query successful. Columns:', messages.fields.map(f => f.name).join(', '));
    
  } catch (error) {
    console.error('Database test failed:', error);
  } finally {
    await pool.end();
  }
}

testDb();
