const axios = require('axios');
require('dotenv').config();

async function testFCMEndpoint() {
  console.log('=== Testing FCM Token Registration Endpoint ===');
  
  try {
    // First login to get a token
    console.log('\n1. Logging in to get auth token...');
    const loginResponse = await axios.post(`${process.env.API_BASE_URL || 'http://localhost:3000'}/api/v1/auth/login`, {
      email: 'brichabhi@gmail.com',
      password: 'password123'
    });
    
    const accessToken = loginResponse.data.access || loginResponse.data.access_token;
    console.log('✓ Login successful, got access token');
    
    // Test FCM token registration
    console.log('\n2. Testing FCM token registration...');
    const testToken = 'test_fcm_token_' + Date.now();
    
    const fcmResponse = await axios.put(`${process.env.API_BASE_URL || 'http://localhost:3000'}/api/v1/fcm/token`, {
      fcm_token: testToken
    }, {
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      }
    });
    
    console.log('✓ FCM token registration response:', fcmResponse.data);
    
    // Verify token was stored
    console.log('\n3. Verifying token storage...');
    const { Pool } = require('pg');
    const pool = new Pool({
      connectionString: process.env.DATABASE_URL,
      ssl: process.env.DATABASE_URL.includes('sslmode=require') 
        ? { rejectUnauthorized: false } 
        : false
    });
    
    const { rows } = await pool.query('SELECT fcm_token FROM users WHERE email = $1', ['brichabhi@gmail.com']);
    if (rows[0]?.fcm_token === testToken) {
      console.log('✓ FCM token successfully stored in database');
    } else {
      console.log('✗ FCM token not found in database');
    }
    
    await pool.end();
    
  } catch (error) {
    console.error('Test failed:', error.response?.data || error.message);
  }
}

testFCMEndpoint();
