package logger

import (
	"os"
	"time"

	"github.com/rs/zerolog"
)

func New(env string) zerolog.Logger {
	zerolog.TimeFieldFormat = time.RFC3339Nano
	lvl := zerolog.InfoLevel
	if env == "dev" {
		lvl = zerolog.DebugLevel
	}
	logger := zerolog.New(os.Stdout).Level(lvl).With().Timestamp().Logger()
	return logger
}
