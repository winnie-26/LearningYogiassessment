package config

import (
	"fmt"

	"github.com/caarlos0/env/v10"
)

type Config struct {
	Env                 string `env:"APP_ENV" envDefault:"dev"`
	HTTPPort            string `env:"HTTP_PORT" envDefault:"8080"`
	DatabaseURL         string `env:"DATABASE_URL,required"`
	JWTAccessSecret     string `env:"JWT_ACCESS_SECRET,required"`
	JWTRefreshSecret    string `env:"JWT_REFRESH_SECRET,required"`
	AccessTokenMinutes  int    `env:"ACCESS_TOKEN_MINUTES" envDefault:"15"`
	RefreshTokenDays    int    `env:"REFRESH_TOKEN_DAYS" envDefault:"7"`
	MasterKey           string `env:"MASTER_KEY,required"` // 32 bytes base64 or hex
	RateLimitPerMinute  int    `env:"AUTH_RATE_LIMIT_PER_MIN" envDefault:"60"`
	FirebaseCredentials string `env:"FIREBASE_CREDENTIALS_JSON"` // optional JSON string
}

func Load() (*Config, error) {
	cfg := &Config{}
	if err := env.Parse(cfg); err != nil {
		return nil, fmt.Errorf("parse env: %w", err)
	}
	return cfg, nil
}
