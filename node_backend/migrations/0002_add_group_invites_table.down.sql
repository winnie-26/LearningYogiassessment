-- Drop the trigger and function first
DROP TRIGGER IF EXISTS update_group_invites_updated_at ON group_invites;
DROP FUNCTION IF EXISTS update_updated_at_column();

-- Drop the indexes
DROP INDEX IF EXISTS idx_group_invites_group_id;
DROP INDEX IF EXISTS idx_group_invites_user_id;
DROP INDEX IF EXISTS idx_group_invites_status;

-- Finally, drop the table
DROP TABLE IF EXISTS group_invites;
