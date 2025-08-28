package store

import (
	"context"

	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
	"github.com/rs/zerolog"
	"secure-messaging-backend/internal/config"
)

func Connect(ctx context.Context, cfg *config.Config) (*sqlx.DB, error) {
	db, err := sqlx.Open("postgres", cfg.DatabaseURL)
	if err != nil {
		return nil, err
	}
	if err := db.PingContext(ctx); err != nil {
		return nil, err
	}
	return db, nil
}

// WithLogger demonstrates how we'd add logging hooks later if needed
func WithLogger(db *sqlx.DB, log zerolog.Logger) *sqlx.DB { return db }
