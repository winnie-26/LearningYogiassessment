-- Remove FCM token column from users table
DROP INDEX IF EXISTS idx_users_fcm_token;
ALTER TABLE users DROP COLUMN IF EXISTS fcm_token;
