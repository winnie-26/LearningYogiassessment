# Private Groups and Invitation System

This document explains the private group functionality and invitation system implemented in the LearningYogi Chat application.

## Overview

The system now supports two types of groups:
- **Public Groups**: Anyone can join without an invitation
- **Private Groups**: Users need an invitation to join

## Database Schema

### New Table: `group_invites`

```sql
CREATE TABLE group_invites (
    id BIGSERIAL PRIMARY KEY,
    group_id BIGINT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    inviter_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' 
        CHECK (status IN ('pending', 'accepted', 'declined', 'revoked')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(group_id, user_id)
);
```

## API Endpoints

### Check if User Can Join a Group

```http
GET /api/v1/groups/:id/can-join
```

**Response**
```json
{
  "canJoin": true,
  "isMember": false,
  "requiresInvite": true,
  "message": "You have a pending invitation to join this private group"
}
```

### Create an Invitation

```http
POST /api/v1/groups/:groupId/invites
```

**Request Body**
```json
{
  "user_id": 123
}
```

### List Group Invitations

```http
GET /api/v1/groups/:groupId/invites?status=pending
```

### Respond to an Invitation

```http
POST /api/v1/groups/:groupId/invites/:inviteId/respond
```

**Request Body**
```json
{
  "action": "accept" // or "decline"
}
```

### Revoke an Invitation

```http
DELETE /api/v1/groups/:groupId/invites/:inviteId
```

## Integration with Group Joining

When a user attempts to join a group:
1. The system checks if the group is private
2. If private, verifies the user has a pending invitation
3. If no invitation exists, returns a 403 Forbidden with error code `invitation_required`
4. If invitation exists, marks it as accepted and adds the user to the group

## Error Codes

- `invitation_required`: User needs an invitation to join this private group
- `group_full`: Group has reached maximum capacity
- `already_member`: User is already a member of the group
- `invite_exists`: An invitation already exists for this user

## Running Migrations

To apply the database changes:

```bash
# Apply migration
npm run migrate

# Rollback migration (if needed)
npm run migrate:rollback
```

## Frontend Integration

The frontend should:
1. Check `GET /api/v1/groups/:id/can-join` before showing join buttons
2. Show appropriate UI based on the response (e.g., "Request to Join" for private groups)
3. Handle error responses gracefully and show user-friendly messages
