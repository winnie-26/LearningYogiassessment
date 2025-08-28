package main

import (
	"context"
	"log"
	"net/http"
	"os"

	"secure-messaging-backend/internal/api"
	"secure-messaging-backend/internal/config"
	"secure-messaging-backend/internal/logger"
	"secure-messaging-backend/internal/store"
)

func main() {
	// Load config
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}

	// Logger
	logg := logger.New(cfg.Env)
	ctx := logg.WithContext(context.Background())

	// DB
	db, err := store.Connect(ctx, cfg)
	if err != nil {
		logg.Fatal().Err(err).Msg("db connect failed")
	}
	defer db.Close()

	// Router / Server
	e := api.NewServer(cfg, logg, db)

	addr := ":" + cfg.HTTPPort
	if v := os.Getenv("PORT"); v != "" {
		addr = ":" + v
	}
	logg.Info().Str("addr", addr).Msg("starting server")
	if err := e.Start(addr); err != nil && err != http.ErrServerClosed {
		logg.Fatal().Err(err).Msg("server error")
	}
}
