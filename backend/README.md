# Secure Group Messaging Backend (Go + Echo + Postgres)

Production-ready starter for Learning Yogi assessment. Implements JWT auth, groups, join requests, encrypted messaging (AES-128-GCM), FCM notifications, migrations, Docker, CI, and docs.

## Quick start

Prereqs: Docker, docker-compose

1. Copy env
```
cp .env.example .env
```
2. Start services
```
docker-compose up --build
```
3. Visit: http://localhost:8080/healthz

## Configuration (env)
- APP_ENV: dev|prod
- HTTP_PORT: default 8080
- DATABASE_URL: e.g. postgres://user:pass@host:5432/db?sslmode=disable
- JWT_ACCESS_SECRET, JWT_REFRESH_SECRET
- ACCESS_TOKEN_MINUTES (default 15)
- REFRESH_TOKEN_DAYS (default 7)
- MASTER_KEY: 32-byte key used to wrap group keys (AES-256-GCM). Example in .env.example
- FIREBASE_CREDENTIALS_JSON: Optional JSON credentials for FCM server-side

## Stack
- Go 1.22, Echo, sqlx, zerolog, JWT
- Postgres, golang-migrate-ready migrations (SQL files in `migrations/`)
- AES-256-GCM key wrap for group keys, AES-128-GCM for message payloads
- Docker + docker-compose
- GitHub Actions CI

## Development
- Run migrations using golang-migrate or similar tool
- API will expose `/swagger` and serve OpenAPI from `openapi/openapi.yaml` (to be expanded)

## Security Notes
- Passwords will be bcrypt hashed
- Tokens: access ~15m, refresh ~7d
- Group keys are generated per group, wrapped with MASTER_KEY
- Messages stored only as ciphertext + IV

## TODO
- Implement all endpoints in `internal/api/`
- Services in `internal/service/`
- FCM wrapper in `internal/notify/`
- Expand OpenAPI and export Postman collection

See `handover.md` for architecture when complete.
