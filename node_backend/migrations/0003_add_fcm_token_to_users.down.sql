-- Remove fcm_token column from users table
ALTER TABLE users 
DROP COLUMN IF EXISTS fcm_token;
