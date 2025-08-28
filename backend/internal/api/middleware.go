package api

import (
	"net/http"
	"strconv"

	"github.com/golang-jwt/jwt/v5"
	"github.com/labstack/echo/v4"
)

const ctxUserIDKey = "user_id"

func JWTMiddleware(secret string) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			auth := c.Request().Header.Get("Authorization")
			if len(auth) < 8 || auth[:7] != "Bearer " {
				return c.JSON(http.StatusUnauthorized, echo.Map{"error": "missing bearer token"})
			}
			tokStr := auth[7:]
			tok, err := jwt.Parse(tokStr, func(token *jwt.Token) (interface{}, error) {
				if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
					return nil, echo.ErrUnauthorized
				}
				return []byte(secret), nil
			})
			if err != nil || !tok.Valid {
				return c.JSON(http.StatusUnauthorized, echo.Map{"error": "invalid token"})
			}
			claims, ok := tok.Claims.(jwt.MapClaims)
			if !ok { return c.JSON(http.StatusUnauthorized, echo.Map{"error": "invalid claims"}) }
			sub, _ := claims["sub"].(string)
			uid, err := strconv.ParseInt(sub, 10, 64)
			if err != nil { return c.JSON(http.StatusUnauthorized, echo.Map{"error": "invalid subject"}) }
			c.Set(ctxUserIDKey, uid)
			return next(c)
		}
	}
}

func GetUserID(c echo.Context) (int64, bool) {
	v := c.Get(ctxUserIDKey)
	if v == nil { return 0, false }
	id, ok := v.(int64)
	return id, ok
}
