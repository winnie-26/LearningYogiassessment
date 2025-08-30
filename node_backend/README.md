# Learning Yogi Assessment - Node.js Backend

A Node.js REST API server with WebSocket support for real-time group messaging and Firebase push notifications.

## Features

- **JWT Authentication** - Secure user login/registration with token-based auth
- **Real-time Messaging** - WebSocket server for instant group chat
- **Group Management** - Private groups with invitation system
- **Push Notifications** - Firebase Cloud Messaging (FCM) integration
- **PostgreSQL Database** - Persistent data storage with migrations
- **RESTful API** - Express.js with structured routing and middleware

## Architecture

### Core Technologies
- **Express.js** - Web framework and REST API
- **Socket.IO** - WebSocket server for real-time communication
- **PostgreSQL** - Primary database with connection pooling
- **Firebase Admin SDK** - Push notification delivery
- **JWT** - Stateless authentication tokens

### Key Modules
- `auth.service.js` - User authentication and JWT handling
- `messages.service.js` - Group messaging and WebSocket integration
- `fcm.service.js` - Firebase Cloud Messaging token management
- `notification.service.js` - Push notification delivery
- `websocket-server.js` - Real-time WebSocket connection handling

## Setup Instructions

### Prerequisites
- Node.js (16+)
- PostgreSQL (13+)
- Firebase project with Admin SDK credentials
- Flutter frontend app (see `../frontend/README.md`)

### Installation

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Database setup:**
   ```bash
   # Create PostgreSQL database
   createdb learning_yogi_db
   
   # Run migrations
   npm run migrate:up
   ```

3. **Environment configuration:**
   Create `.env` file:
   ```env
   DATABASE_URL=postgresql://username:password@localhost:5432/learning_yogi_db
   JWT_SECRET=your-super-secret-jwt-key
   PORT=3000
   
   # Firebase Admin SDK (from Firebase Console)
   FIREBASE_PROJECT_ID=your-project-id
   FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
   FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com
   ```

4. **Start the server:**
   ```bash
   # Development mode
   npm run dev
   
   # Production mode
   npm start
   ```

### Firebase Admin SDK Setup

1. Go to Firebase Console → Project Settings → Service Accounts
2. Generate new private key (downloads JSON file)
3. Extract credentials to environment variables:
   - `FIREBASE_PROJECT_ID`
   - `FIREBASE_PRIVATE_KEY` 
   - `FIREBASE_CLIENT_EMAIL`

## API Documentation

### Base URL
- **Development:** `http://localhost:3000`
- **WebSocket:** `ws://localhost:3000`

### Authentication Endpoints

#### Register User
```http
POST /api/v1/auth/register
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "securepassword"
}
```

#### Login User
```http
POST /api/v1/auth/login
Content-Type: application/json

{
  "email": "user@example.com", 
  "password": "securepassword"
}
```

**Response:**
```json
{
  "access_token": "jwt-token",
  "refresh_token": "refresh-token",
  "user": {
    "id": 1,
    "email": "user@example.com"
  }
}
```

### Group Management

#### Get User Groups
```http
GET /api/v1/groups
Authorization: Bearer <jwt-token>
```

#### Create Group
```http
POST /api/v1/groups
Authorization: Bearer <jwt-token>
Content-Type: application/json

{
  "name": "My Group",
  "description": "Group description"
}
```

#### Invite User to Group
```http
POST /api/v1/groups/:groupId/invite
Authorization: Bearer <jwt-token>
Content-Type: application/json

{
  "email": "invitee@example.com"
}
```

### Messaging

#### Get Group Messages
```http
GET /api/v1/groups/:groupId/messages
Authorization: Bearer <jwt-token>
```

#### Send Message
```http
POST /api/v1/groups/:groupId/messages
Authorization: Bearer <jwt-token>
Content-Type: application/json

{
  "content": "Hello, group!"
}
```

### FCM Token Management

#### Register FCM Token
```http
PUT /api/v1/fcm/token
Authorization: Bearer <jwt-token>
Content-Type: application/json

{
  "token": "fcm-device-token"
}
```

#### Remove FCM Token
```http
DELETE /api/v1/fcm/token
Authorization: Bearer <jwt-token>
```

## WebSocket Events

### Connection
```javascript
// Client connects with JWT token
socket.emit('authenticate', { token: 'jwt-token', groupId: 123 });
```

### Real-time Messages
```javascript
// Server broadcasts to group members
socket.emit('new_message', {
  id: 1,
  content: "Hello!",
  sender: "user@example.com",
  timestamp: "2024-01-01T00:00:00Z"
});
```

## Database Schema

### Users Table
```sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  fcm_token TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Groups Table
```sql
CREATE TABLE groups (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  created_by INTEGER REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Messages Table
```sql
CREATE TABLE messages (
  id SERIAL PRIMARY KEY,
  group_id INTEGER REFERENCES groups(id),
  sender_id INTEGER REFERENCES users(id),
  content TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Group Members Table
```sql
CREATE TABLE group_members (
  group_id INTEGER REFERENCES groups(id),
  user_id INTEGER REFERENCES users(id),
  joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (group_id, user_id)
);
```

## Push Notifications

### Notification Types
- **New Message** - When user receives a message in subscribed group
- **Group Invite** - When user is invited to join a group
- **Invite Accepted** - When someone accepts your group invitation

### FCM Integration
- Automatic token registration during login
- Token cleanup on logout
- Retry logic for failed deliveries
- Comprehensive logging for debugging

## Development

### Database Migrations
```bash
# Run pending migrations
npm run migrate:up

# Rollback last migration
npm run migrate:down

# Create new migration
npm run migrate:create <migration_name>
```

### Debug Scripts
```bash
# Test FCM configuration
node debug-fcm.js

# Test FCM endpoint manually
node test-fcm-endpoint.js
```

### Logging
- Request/response logging via middleware
- WebSocket connection tracking
- FCM token registration logging
- Push notification delivery logging

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `DATABASE_URL` | PostgreSQL connection string | Yes |
| `JWT_SECRET` | Secret key for JWT signing | Yes |
| `PORT` | Server port (default: 3000) | No |
| `FIREBASE_PROJECT_ID` | Firebase project ID | Yes |
| `FIREBASE_PRIVATE_KEY` | Firebase Admin SDK private key | Yes |
| `FIREBASE_CLIENT_EMAIL` | Firebase Admin SDK client email | Yes |

## Deployment

### Production Build
```bash
# Install production dependencies
npm ci --only=production

# Start production server
npm start
```

### Docker (Optional)
```dockerfile
FROM node:16-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
```

## Testing

### API Testing
```bash
# Test authentication
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password"}'

# Test FCM token registration
curl -X PUT http://localhost:3000/api/v1/fcm/token \
  -H "Authorization: Bearer <jwt-token>" \
  -H "Content-Type: application/json" \
  -d '{"token":"fcm-token-here"}'
```

### WebSocket Testing
Use tools like Postman or custom WebSocket clients to test real-time messaging.

## Troubleshooting

### Database Connection Issues
```bash
# Check PostgreSQL status
brew services list | grep postgresql

# Start PostgreSQL
brew services start postgresql
```

### Firebase Admin SDK Issues
- Verify environment variables are properly set
- Check Firebase project permissions
- Ensure service account has FCM permissions

### WebSocket Connection Problems
- Check CORS configuration
- Verify JWT token format
- Monitor connection logs in console

## Project Structure

```
src/
├── middleware/           # Express middleware (auth, logging)
├── modules/             # Business logic modules
│   ├── auth.controller.js
│   ├── auth.service.js
│   ├── fcm.controller.js
│   ├── fcm.service.js
│   ├── groups.controller.js
│   ├── groups.service.js
│   ├── messages.controller.js
│   └── messages.service.js
├── routes/              # API route definitions
│   ├── modules/
│   └── index.js
├── services/            # External service integrations
│   └── notification.service.js
├── websocket/           # WebSocket server implementation
│   └── websocket-server.js
└── app.js              # Express app configuration

migrations/              # Database migration files
scripts/                # Utility and debug scripts
```

## Security

### Authentication
- JWT tokens with expiration
- Password hashing with bcrypt
- Protected routes with auth middleware

### Data Protection
- Input validation and sanitization
- SQL injection prevention via parameterized queries
- CORS configuration for frontend access

### Firebase Security
- Service account credentials via environment variables
- FCM token validation before sending notifications
- User-specific token management

## Performance

### Database Optimization
- Connection pooling for PostgreSQL
- Indexed columns for frequent queries
- Efficient JOIN operations for group/message queries

### WebSocket Optimization
- Group-based message broadcasting
- Connection cleanup on disconnect
- Memory-efficient connection tracking

## Monitoring

### Logging Levels
- **Info:** Successful operations and key events
- **Debug:** Detailed operation tracking
- **Error:** Failed operations and exceptions

### Health Checks
- Database connectivity verification
- Firebase Admin SDK status
- WebSocket server status

## Support

For technical support:
- **Database Issues:** Check PostgreSQL logs and connection settings
- **Firebase Problems:** Verify Admin SDK configuration and permissions
- **WebSocket Issues:** Monitor connection logs and network connectivity
- **Frontend Integration:** See `../frontend/README.md`
