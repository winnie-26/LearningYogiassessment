const { Pool } = require('pg');
require('dotenv').config();

async function checkSchema() {
  const pool = new Pool({ 
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false }
  });

  try {
    // Check messages table
    const messagesRes = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'messages';
    `);
    
    console.log('Messages table columns:');
    console.table(messagesRes.rows);

    // Check if there's any data in messages
    const countRes = await pool.query('SELECT COUNT(*) FROM messages');
    console.log('Total messages:', countRes.rows[0].count);

  } catch (error) {
    console.error('Error checking schema:', error);
  } finally {
    await pool.end();
  }
}

checkSchema();
