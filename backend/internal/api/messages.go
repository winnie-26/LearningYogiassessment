package api

import (
	"net/http"
	"strconv"
	"time"

	"github.com/labstack/echo/v4"
	"secure-messaging-backend/internal/service"
)

type sendMessageReq struct {
	Text string `json:"text"`
}

type messageResp struct {
	ID        int64     `json:"id"`
	SenderID  int64     `json:"sender_id"`
	Text      string    `json:"text"`
	CreatedAt time.Time `json:"created_at"`
}

func SendMessageHandler(s *service.MessageService) echo.HandlerFunc {
	return func(c echo.Context) error {
		uid, ok := GetUserID(c)
		if !ok { return c.JSON(http.StatusUnauthorized, echo.Map{"error": "unauthorized"}) }
		gid, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": "invalid group id"}) }
		var req sendMessageReq
		if err := c.Bind(&req); err != nil || req.Text == "" {
			return c.JSON(http.StatusBadRequest, echo.Map{"error": "text required"})
		}
		msg, err := s.Send(c.Request().Context(), service.SendMessageInput{
			GroupID:  gid,
			SenderID: uid,
			Plain:    []byte(req.Text),
		})
		if err != nil {
			return c.JSON(http.StatusBadRequest, echo.Map{"error": err.Error()})
		}
		return c.JSON(http.StatusCreated, messageResp{ID: msg.ID, SenderID: msg.SenderID, Text: string(msg.Plain), CreatedAt: msg.CreatedAt})
	}
}

func ListMessagesHandler(s *service.MessageService) echo.HandlerFunc {
	return func(c echo.Context) error {
		uid, ok := GetUserID(c)
		if !ok { return c.JSON(http.StatusUnauthorized, echo.Map{"error": "unauthorized"}) }
		gid, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": "invalid group id"}) }
		limit := 50
		if l := c.QueryParam("limit"); l != "" {
			if n, err := strconv.Atoi(l); err == nil { limit = n }
		}
		var beforePtr *time.Time
		if b := c.QueryParam("before"); b != "" {
			if t, err := time.Parse(time.RFC3339, b); err == nil { beforePtr = &t }
		}
		rows, err := s.List(c.Request().Context(), gid, uid, limit, beforePtr)
		if err != nil {
			return c.JSON(http.StatusBadRequest, echo.Map{"error": err.Error()})
		}
		out := make([]messageResp, 0, len(rows))
		for _, r := range rows {
			out = append(out, messageResp{ID: r.ID, SenderID: r.SenderID, Text: string(r.Plain), CreatedAt: r.CreatedAt})
		}
		return c.JSON(http.StatusOK, echo.Map{"messages": out})
	}
}
