package store

import (
	"context"
	"time"

	"github.com/jmoiron/sqlx"
)

type User struct {
	ID           int64     `db:"id"`
	Email        string    `db:"email"`
	PasswordHash string    `db:"password_hash"`
	CreatedAt    time.Time `db:"created_at"`
}

type RefreshToken struct {
	ID        int64     `db:"id"`
	UserID    int64     `db:"user_id"`
	Token     string    `db:"token"`
	ExpiresAt time.Time `db:"expires_at"`
	CreatedAt time.Time `db:"created_at"`
}

type UserStore struct{ db *sqlx.DB }

func NewUserStore(db *sqlx.DB) *UserStore { return &UserStore{db: db} }

func (s *UserStore) CreateUser(ctx context.Context, email, passwordHash string) (*User, error) {
	u := &User{}
	err := s.db.QueryRowxContext(ctx,
		`INSERT INTO users (email, password_hash) VALUES ($1, $2) RETURNING id, email, password_hash, created_at`,
		email, passwordHash,
	).StructScan(u)
	return u, err
}

func (s *UserStore) GetUserByEmail(ctx context.Context, email string) (*User, error) {
	u := &User{}
	err := s.db.GetContext(ctx, u, `SELECT id, email, password_hash, created_at FROM users WHERE email=$1`, email)
	return u, err
}

func (s *UserStore) GetUserByID(ctx context.Context, id int64) (*User, error) {
	u := &User{}
	err := s.db.GetContext(ctx, u, `SELECT id, email, password_hash, created_at FROM users WHERE id=$1`, id)
	return u, err
}

func (s *UserStore) CreateRefreshToken(ctx context.Context, userID int64, token string, expiresAt time.Time) error {
	_, err := s.db.ExecContext(ctx, `INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES ($1, $2, $3)`, userID, token, expiresAt)
	return err
}

func (s *UserStore) GetRefreshToken(ctx context.Context, token string) (*RefreshToken, error) {
	r := &RefreshToken{}
	err := s.db.GetContext(ctx, r, `SELECT id, user_id, token, expires_at, created_at FROM refresh_tokens WHERE token=$1`, token)
	return r, err
}

func (s *UserStore) DeleteRefreshToken(ctx context.Context, token string) error {
	_, err := s.db.ExecContext(ctx, `DELETE FROM refresh_tokens WHERE token=$1`, token)
	return err
}
