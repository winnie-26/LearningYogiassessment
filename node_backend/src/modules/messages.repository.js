const store = require('../data/store');
const { isDbEnabled, getPool } = require('../data/db');

async function add(client, groupId, userId, text) {
  console.log('add called with:', { groupId, userId, text });
  
  if (!isDbEnabled()) {
    console.log('Using in-memory store');
    return store.addMessage(groupId, userId, text);
  }
  
  const useDbClient = client !== undefined;
  console.log(`Using ${useDbClient ? 'provided client' : 'new connection pool'}`);
  
  const queryFn = async (queryObj) => {
    console.log('Executing query:', {
      text: queryObj.text,
      values: queryObj.values,
      useDbClient
    });
    
    try {
      let result;
      if (useDbClient) {
        console.log('Using provided client');
        result = await client.query(queryObj);
      } else {
        console.log('Creating new connection pool');
        const pool = getPool();
        if (!pool) {
          throw new Error('Database pool is not available');
        }
        result = await pool.query(queryObj);
      }
      console.log('Query successful, rows returned:', result.rows.length);
      return result;
    } catch (error) {
      console.error('Query execution failed:', {
        error: error.message,
        code: error.code,
        detail: error.detail,
        query: queryObj.text,
        values: queryObj.values
      });
      throw error;
    }
  };
  
  try {
    // For now, we'll use the text as ciphertext and a fixed IV
    // In production, you should use proper encryption
    const iv = 'fixed-iv-for-now';
    const ciphertext = text || ''; // Ensure ciphertext is not null
    
    // Build the query with all required fields
    const queryText = `
      INSERT INTO messages (
        group_id, 
        user_id,
        text,
        ciphertext,
        iv,
        created_at
      ) VALUES (
        $1::bigint, 
        $2::bigint,
        $3,
        $4,
        $5,
        NOW()
      ) RETURNING id, group_id, user_id, created_at, text`;
      
    const queryValues = [
      groupId, 
      userId, 
      text,    // Storing plain text for now
      ciphertext,
      iv
    ];
    
    console.log('Executing query with values:', { queryText, queryValues });
    
    const { rows } = await queryFn({ 
      text: queryText,
      values: queryValues 
    });
    
    console.log('Message added successfully:', rows[0]);
    
    // Return the message with the text field for backward compatibility
    return { 
      id: rows[0].id,
      group_id: rows[0].group_id,
      user_id: rows[0].user_id,
      text: text,
      created_at: rows[0].created_at
    };
  } catch (err) {
    console.error('Error in add function:', {
      error: err.message,
      stack: err.stack,
      groupId,
      userId,
      textLength: text?.length
    });
    throw err;
  }
}

async function list(client, groupId, { limit = 20, before = null } = {}) {
  console.log('list called with:', { 
    groupId, 
    limit,
    clientExists: !!client,
    isDbEnabled: isDbEnabled()
  });
  
  if (!isDbEnabled()) {
    console.log('Using in-memory store');
    return store.listMessages(groupId, { limit });
  }
  
  const useDbClient = client !== undefined;
  console.log(`Using ${useDbClient ? 'provided client' : 'new connection pool'}`);
  
  const queryFn = async (queryObj) => {
    console.log('Executing query:', {
      text: queryObj.text,
      values: queryObj.values,
      useDbClient
    });
    
    try {
      let result;
      if (useDbClient) {
        console.log('Using provided client');
        result = await client.query(queryObj);
      } else {
        console.log('Creating new connection pool');
        const pool = getPool();
        if (!pool) {
          throw new Error('Database pool is not available');
        }
        result = await pool.query(queryObj);
      }
      console.log('Query successful, rows returned:', result.rows.length);
      return result;
    } catch (error) {
      console.error('Query execution failed:', {
        error: error.message,
        code: error.code,
        detail: error.detail,
        query: queryObj.text,
        values: queryObj.values
      });
      throw error;
    }
  };
  
  // Build the query dynamically based on whether limit is provided
  let queryText = `
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
      u.email AS sender_email,
      SPLIT_PART(u.email, '@', 1) AS sender_name
    FROM messages m
    JOIN users u ON u.id = CASE 
      WHEN m.user_id IS NOT NULL THEN m.user_id 
      ELSE m.sender_id 
    END
    WHERE m.group_id = $1`;
  
  const queryValues = [groupId];
  
  // Add condition for pagination (before timestamp)
  if (before) {
    queryText += ' AND m.created_at < $2';
    queryValues.push(new Date(before).toISOString());
  }
  
  // Always order by created_at DESC for pagination
  queryText += ' ORDER BY m.created_at DESC';
  
  // Add LIMIT
  queryText += ` LIMIT $${queryValues.length + 1}`;
  queryValues.push(limit);
  
  console.log('Final query:', queryText);
  console.log('Query values:', queryValues);
  
  try {
    const { rows } = await queryFn({ text: queryText, values: queryValues });
    console.log('Rows returned:', rows.length);
    
    // Return the rows in ascending order (oldest first) for display
    const sortedRows = [...rows].sort((a, b) => 
      new Date(a.created_at) - new Date(b.created_at)
    );
    
    return sortedRows.map(row => ({
      id: row.id,
      group_id: row.group_id,
      user_id: row.user_id,
      text: row.text,
      created_at: row.created_at,
      sender: {
        id: row.user_id,
        name: row.sender_name || row.sender_email?.split('@')[0] || 'Unknown',
        email: row.sender_email || 'no-email'
      }
    }));
  } catch (error) {
    console.error('Error in list function:', error);
    throw error;
  }
}

async function remove(client, groupId, messageId) {
  if (!isDbEnabled()) {
    // In-memory store API may differ; implement a simple filter if available
    if (typeof store.deleteMessage === 'function') {
      return store.deleteMessage(groupId, messageId);
    }
    if (typeof store._messages === 'object') {
      const key = String(groupId);
      const arr = store._messages[key] || [];
      const before = arr.length;
      store._messages[key] = arr.filter(m => String(m.id) !== String(messageId));
      return { ok: true, deleted: before - store._messages[key].length };
    }
    return { ok: true };
  }
  const useDbClient = !!client;
  const query = async (q) => {
    if (useDbClient) return client.query(q);
    const pool = getPool();
    return pool.query(q);
  };
  await query({
    text: 'DELETE FROM messages WHERE id = $1 AND group_id = $2',
    values: [Number(messageId), Number(groupId)],
  });
  return { ok: true };
}

module.exports = { add, list, remove };
