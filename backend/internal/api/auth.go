package api

import (
	"net/http"

	"github.com/labstack/echo/v4"
	"secure-messaging-backend/internal/service"
)

type registerReq struct {
	Email    string `json:"email" validate:"required,email"`
	Password string `json:"password" validate:"required,min=8"`
}

type loginReq struct {
	Email    string `json:"email" validate:"required,email"`
	Password string `json:"password" validate:"required"`
}

type refreshReq struct {
	RefreshToken string `json:"refresh_token" validate:"required"`
}

func RegisterHandler(s *service.AuthService) echo.HandlerFunc {
	return func(c echo.Context) error {
		req := new(registerReq)
		if err := c.Bind(req); err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": "invalid body"}) }
		if req.Email == "" || req.Password == "" { return c.JSON(http.StatusBadRequest, echo.Map{"error": "email and password required"}) }
		u, err := s.Register(c.Request().Context(), req.Email, req.Password)
		if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": err.Error()}) }
		return c.JSON(http.StatusCreated, echo.Map{"id": u.ID, "email": u.Email})
	}
}

func LoginHandler(s *service.AuthService) echo.HandlerFunc {
	return func(c echo.Context) error {
		req := new(loginReq)
		if err := c.Bind(req); err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": "invalid body"}) }
		u, pair, err := s.Login(c.Request().Context(), req.Email, req.Password)
		if err != nil { return c.JSON(http.StatusUnauthorized, echo.Map{"error": err.Error()}) }
		return c.JSON(http.StatusOK, echo.Map{
			"user": echo.Map{"id": u.ID, "email": u.Email},
			"access_token": pair.AccessToken,
			"refresh_token": pair.RefreshToken,
		})
	}
}

func RefreshHandler(s *service.AuthService) echo.HandlerFunc {
	return func(c echo.Context) error {
		req := new(refreshReq)
		if err := c.Bind(req); err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": "invalid body"}) }
		pair, err := s.Refresh(c.Request().Context(), req.RefreshToken)
		if err != nil { return c.JSON(http.StatusUnauthorized, echo.Map{"error": err.Error()}) }
		return c.JSON(http.StatusOK, echo.Map{
			"access_token": pair.AccessToken,
			"refresh_token": pair.RefreshToken,
		})
	}
}
