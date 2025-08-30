# Learning Yogi Assessment - Flutter Frontend

A Flutter mobile application for real-time group messaging with Firebase push notifications.

## Features

- **User Authentication** - JWT-based login/registration with secure token storage
- **Real-time Messaging** - WebSocket-powered group chat with instant message delivery
- **Group Management** - Create, join, and manage private groups with invite system
- **Push Notifications** - Firebase Cloud Messaging (FCM) for message alerts
- **Offline Support** - Secure local storage for authentication tokens
- **Modern UI** - Material Design with responsive layouts

## Architecture

### State Management
- **Flutter Riverpod** for dependency injection and state management
- **Secure Storage** for authentication tokens and sensitive data
- **Shared Preferences** for user preferences

### API Integration
- **Dio HTTP Client** with interceptors for authentication
- **WebSocket Client** for real-time messaging
- **Firebase Messaging** for push notifications

### Key Services
- `AuthRepository` - Handles login, registration, and token management
- `FcmService` - Manages Firebase Cloud Messaging tokens and notifications
- `ApiClient` - HTTP client with authentication and error handling
- `NotificationService` - Local notification handling and navigation

## Setup Instructions

### Prerequisites
- Flutter SDK (3.0+)
- Android Studio / Xcode
- Firebase project with FCM enabled
- Node.js backend running (see `../node_backend/README.md`)

### Installation

1. **Install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Configure Firebase:**
   - Place `google-services.json` in `android/app/`
   - Place `GoogleService-Info.plist` in `ios/Runner/`

3. **Run the app:**
   ```bash
   # Debug mode
   flutter run
   
   # Release mode
   flutter run --release
   
   # Build APK
   flutter build apk
   ```

### Firebase Configuration

The app requires Firebase project setup with:
- **Authentication** enabled
- **Cloud Messaging (FCM)** enabled
- **Firestore** (optional for future features)

### Environment Variables

Configure in your Firebase project:
- Package name: `com.example.frontend`
- SHA-1 fingerprints for release builds

## API Endpoints

The app connects to the Node.js backend at:
- **Base URL:** `http://10.0.2.2:3000` (Android emulator)
- **WebSocket:** `ws://10.0.2.2:3000`

### Authentication
- `POST /api/v1/auth/login` - User login
- `POST /api/v1/auth/register` - User registration

### Groups
- `GET /api/v1/groups` - List user groups
- `POST /api/v1/groups` - Create new group
- `POST /api/v1/groups/:id/invite` - Invite user to group

### Messages
- `GET /api/v1/groups/:id/messages` - Get group messages
- `POST /api/v1/groups/:id/messages` - Send message

### FCM Tokens
- `PUT /api/v1/fcm/token` - Register FCM token
- `DELETE /api/v1/fcm/token` - Remove FCM token

## Development Notes

### FCM Token Registration
- Automatic registration during login/registration
- Token removal on logout
- Retry logic for emulator compatibility
- Comprehensive error logging

### WebSocket Connection
- Auto-reconnection on network changes
- Group-based message broadcasting
- Real-time typing indicators (future feature)

### Error Handling
- Network error recovery
- Token refresh handling
- Graceful degradation when FCM unavailable

## Troubleshooting

### FCM Issues in Emulator
```
E/FirebaseMessaging: Firebase Installations Service is unavailable
```
**Solution:** Use physical device or emulator with Google Play Services.

### Network Connection Issues
- Ensure backend is running on `localhost:3000`
- Use `10.0.2.2:3000` for Android emulator
- Check firewall settings

### Authentication Errors
- Verify JWT tokens in secure storage
- Check token expiration
- Ensure backend auth middleware is working

## Project Structure

```
lib/
├── core/                    # Core utilities and constants
├── data/
│   ├── api/                # API client and HTTP services
│   └── repositories/       # Data layer abstractions
├── features/
│   ├── auth/              # Authentication screens
│   ├── groups/            # Group management
│   ├── messages/          # Messaging interface
│   └── notifications/     # FCM service
├── services/              # Platform services
└── main.dart             # App entry point
```

## Dependencies

### Core
- `flutter_riverpod` - State management
- `dio` - HTTP client
- `web_socket_channel` - WebSocket connectivity

### Storage
- `flutter_secure_storage` - Secure token storage
- `shared_preferences` - User preferences

### Firebase
- `firebase_core` - Firebase initialization
- `firebase_messaging` - Push notifications

### UI
- `material_design_icons_flutter` - Icons
- `flutter_launcher_icons` - App icons

## Testing

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter test integration_test/
```

### Manual Testing Checklist
- [ ] User registration and login
- [ ] Group creation and joining
- [ ] Real-time message sending/receiving
- [ ] Push notification delivery (physical device)
- [ ] Logout and token cleanup

## Build & Deploy

### Debug Build
```bash
flutter run
```

### Release APK
```bash
flutter build apk --release
```

### App Bundle (Google Play)
```bash
flutter build appbundle --release
```

## Support

For issues related to:
- **Backend API:** See `../node_backend/README.md`
- **Firebase Setup:** Check Firebase Console configuration
- **Flutter Development:** Refer to [Flutter Documentation](https://docs.flutter.dev/)
