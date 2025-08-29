const { Pool } = require('pg');
require('dotenv').config();

async function testQuery() {
  const pool = new Pool({ 
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false }
  });

  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');
    
    // Test with a known group ID (replace 1 with an actual group ID from your database)
    const groupId = 1;
    
    console.log('Testing with groupId:', groupId);
    
    // Try the exact query we're using in the repository
    const queryText = `
      SELECT 
        m.id,
        m.group_id,
        CASE 
          WHEN m.user_id IS NOT NULL THEN m.user_id 
          ELSE m.sender_id 
        END as user_id,
        CASE 
          WHEN m.text IS NOT NULL THEN m.text
          ELSE m.ciphertext 
        END as text,
        m.created_at,
        u.email AS sender_email
      FROM messages m
      JOIN users u ON u.id = CASE 
        WHEN m.user_id IS NOT NULL THEN m.user_id 
        ELSE m.sender_id 
      END
      WHERE m.group_id = $1
      ORDER BY m.created_at DESC
      LIMIT 10`;
    
    console.log('Executing query...');
    const result = await client.query(queryText, [groupId]);
    
    console.log('Query successful!');
    console.log('Found', result.rows.length, 'messages');
    
    if (result.rows.length > 0) {
      console.log('First message:', {
        id: result.rows[0].id,
        group_id: result.rows[0].group_id,
        user_id: result.rows[0].user_id,
        text: result.rows[0].text,
        created_at: result.rows[0].created_at,
        sender_email: result.rows[0].sender_email
      });
    }
    
    await client.query('ROLLBACK');
  } catch (error) {
    console.error('Error in test query:', error);
    await client.query('ROLLBACK');
  } finally {
    client.release();
    await pool.end();
  }
}

testQuery();
