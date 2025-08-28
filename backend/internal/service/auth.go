package service

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
	"secure-messaging-backend/internal/config"
	"secure-messaging-backend/internal/store"
)

type AuthService struct {
	cfg       *config.Config
	users     *store.UserStore
}

func NewAuthService(cfg *config.Config, users *store.UserStore) *AuthService {
	return &AuthService{cfg: cfg, users: users}
}

type TokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
}

func (s *AuthService) Register(ctx context.Context, email, password string) (*store.User, error) {
	if len(password) < 8 {
		return nil, errors.New("password too short")
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil { return nil, err }
	u, err := s.users.CreateUser(ctx, email, string(hash))
	return u, err
}

func (s *AuthService) Login(ctx context.Context, email, password string) (*store.User, *TokenPair, error) {
	u, err := s.users.GetUserByEmail(ctx, email)
	if err != nil { return nil, nil, err }
	if err := bcrypt.CompareHashAndPassword([]byte(u.PasswordHash), []byte(password)); err != nil {
		return nil, nil, errors.New("invalid credentials")
	}
	pair, err := s.issueTokens(ctx, u.ID)
	if err != nil { return nil, nil, err }
	return u, pair, nil
}

func (s *AuthService) Refresh(ctx context.Context, refreshToken string) (*TokenPair, error) {
	rt, err := s.users.GetRefreshToken(ctx, refreshToken)
	if err != nil { return nil, errors.New("invalid refresh token") }
	if time.Now().After(rt.ExpiresAt) {
		_ = s.users.DeleteRefreshToken(ctx, refreshToken)
		return nil, errors.New("refresh token expired")
	}
	return s.issueTokens(ctx, rt.UserID)
}

func (s *AuthService) issueTokens(ctx context.Context, userID int64) (*TokenPair, error) {
	accessExp := time.Now().Add(time.Duration(s.cfg.AccessTokenMinutes) * time.Minute)
	accessClaims := jwt.MapClaims{
		"sub": fmt.Sprintf("%d", userID),
		"exp": accessExp.Unix(),
		"type": "access",
	}
	access := jwt.NewWithClaims(jwt.SigningMethodHS256, accessClaims)
	accessStr, err := access.SignedString([]byte(s.cfg.JWTAccessSecret))
	if err != nil { return nil, err }

	// refresh token as random string stored server-side
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil { return nil, err }
	refreshStr := base64.RawURLEncoding.EncodeToString(b)
	refreshExp := time.Now().Add(time.Duration(s.cfg.RefreshTokenDays) * 24 * time.Hour)
	if err := s.users.CreateRefreshToken(ctx, userID, refreshStr, refreshExp); err != nil {
		return nil, err
	}
	return &TokenPair{AccessToken: accessStr, RefreshToken: refreshStr}, nil
}
