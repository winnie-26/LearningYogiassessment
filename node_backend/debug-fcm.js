const { Pool } = require('pg');
require('dotenv').config();

async function debugFCM() {
  console.log('=== FCM Debug Script ===');
  
  try {
    const pool = new Pool({
      connectionString: process.env.DATABASE_URL,
      ssl: process.env.DATABASE_URL.includes('sslmode=require') 
        ? { rejectUnauthorized: false } 
        : false
    });
    
    // Check if users table has fcm_token column
    console.log('\n1. Checking database schema...');
    const schemaResult = await pool.query(`
      SELECT column_name, data_type, is_nullable 
      FROM information_schema.columns 
      WHERE table_name = 'users' AND column_name = 'fcm_token'
    `);
    
    if (schemaResult.rows.length > 0) {
      console.log('✓ fcm_token column exists:', schemaResult.rows[0]);
    } else {
      console.log('✗ fcm_token column does not exist');
      return;
    }
    
    // Check all users and their FCM tokens
    console.log('\n2. Checking FCM tokens in database...');
    const usersResult = await pool.query('SELECT id, email, fcm_token FROM users');
    console.log(`Found ${usersResult.rows.length} users:`);
    
    usersResult.rows.forEach(user => {
      console.log(`- User ${user.id} (${user.email}): ${user.fcm_token ? `Token: ${user.fcm_token.substring(0, 20)}...` : 'No token'}`);
    });
    
    // Test Firebase Admin SDK initialization
    console.log('\n3. Testing Firebase Admin SDK...');
    try {
      const admin = require('firebase-admin');
      if (admin.apps.length > 0) {
        console.log('✓ Firebase Admin SDK is initialized');
        const messaging = admin.messaging();
        console.log('✓ Firebase Messaging service available');
      } else {
        console.log('✗ Firebase Admin SDK not initialized');
      }
    } catch (error) {
      console.log('✗ Firebase Admin SDK error:', error.message);
    }
    
    // Test notification service
    console.log('\n4. Testing notification service...');
    try {
      const notificationService = require('./src/services/notification.service');
      if (notificationService.messaging) {
        console.log('✓ Notification service has messaging instance');
      } else {
        console.log('✗ Notification service missing messaging instance');
      }
    } catch (error) {
      console.log('✗ Notification service error:', error.message);
    }
    
    console.log('\n=== Debug Complete ===');
    
  } catch (error) {
    console.error('Debug script error:', error);
  } finally {
    process.exit(0);
  }
}

debugFCM();
