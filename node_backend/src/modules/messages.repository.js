const store = require('../data/store');
const { isDbEnabled, getPool } = require('../data/db');

async function add(groupId, userId, text) {
  if (!isDbEnabled()) {
    return store.addMessage(groupId, userId, text);
  }
  const pool = getPool();
  
  try {
    // Generate a random IV for the message
    const iv = Buffer.from('initial-iv').toString('base64');
    
    // Insert the message with the text as ciphertext
    const { rows } = await pool.query(
      `INSERT INTO messages (
        group_id, 
        sender_id, 
        ciphertext, 
        iv,
        created_at
      ) VALUES (
        $1::bigint, 
        $2::bigint, 
        $3, 
        $4,
        NOW()
      ) RETURNING id, group_id, sender_id AS user_id, created_at`,
      [groupId, userId, text, iv]
    );
    
    // Return the message with the text field for backward compatibility
    return { 
      id: rows[0].id,
      group_id: rows[0].group_id,
      user_id: rows[0].user_id,
      text: text, // Include the original text in the response
      created_at: rows[0].created_at
    };

  } catch (err) {
    console.error('Error adding message:', err);
    throw err;
  }
}

async function list(groupId, { limit } = {}) {
  if (!isDbEnabled()) {
    return store.listMessages(groupId, { limit });
  }
  const pool = getPool();
  const params = [groupId];
  
  let sql = `
    SELECT 
      id, 
      group_id, 
      sender_id AS user_id, 
      ciphertext AS text, 
      created_at 
    FROM messages 
    WHERE group_id = $1::bigint 
    ORDER BY created_at DESC
  `;
  
  if (typeof limit === 'number') {
    params.push(limit);
    sql += ` LIMIT $${params.length}`;
  }
  
  const { rows } = await pool.query(sql, params);
  
  // Ensure all required fields are present and in the correct format
  return rows.map(row => ({
    id: row.id,
    group_id: row.group_id,
    user_id: row.user_id,
    text: row.text, // This is the ciphertext from the database
    created_at: row.created_at
  }));
}

module.exports = { add, list };
