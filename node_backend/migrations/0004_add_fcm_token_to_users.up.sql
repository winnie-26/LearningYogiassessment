-- Add FCM token column to users table for Firebase push notifications
ALTER TABLE users ADD COLUMN fcm_token TEXT;

-- Add index for faster lookups
CREATE INDEX idx_users_fcm_token ON users(fcm_token) WHERE fcm_token IS NOT NULL;
