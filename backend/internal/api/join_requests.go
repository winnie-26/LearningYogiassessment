package api

import (
	"net/http"
	"strconv"

	"github.com/labstack/echo/v4"
	"secure-messaging-backend/internal/service"
)

func ListJoinRequestsHandler(s *service.JoinRequestService) echo.HandlerFunc {
	return func(c echo.Context) error {
		uid, ok := GetUserID(c)
		if !ok { return c.JSON(http.StatusUnauthorized, echo.Map{"error": "unauthorized"}) }
		gidStr := c.Param("id")
		gid, err := strconv.ParseInt(gidStr, 10, 64)
		if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": "invalid group id"}) }
		list, err := s.ListPending(c.Request().Context(), gid, uid)
		if err != nil { return c.JSON(http.StatusForbidden, echo.Map{"error": err.Error()}) }
		out := make([]echo.Map, 0, len(list))
		for _, jr := range list {
			out = append(out, echo.Map{
				"id": jr.ID,
				"requester_id": jr.RequesterID,
				"status": jr.Status,
				"created_at": jr.CreatedAt,
			})
		}
		return c.JSON(http.StatusOK, echo.Map{"join_requests": out})
	}
}

func ApproveJoinRequestHandler(s *service.JoinRequestService) echo.HandlerFunc {
	return func(c echo.Context) error {
		uid, ok := GetUserID(c)
		if !ok { return c.JSON(http.StatusUnauthorized, echo.Map{"error": "unauthorized"}) }
		gid, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": "invalid group id"}) }
		reqID, err := strconv.ParseInt(c.Param("req_id"), 10, 64)
		if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": "invalid request id"}) }
		if err := s.Approve(c.Request().Context(), gid, uid, reqID); err != nil {
			return c.JSON(http.StatusBadRequest, echo.Map{"error": err.Error()})
		}
		return c.NoContent(http.StatusNoContent)
	}
}

func DeclineJoinRequestHandler(s *service.JoinRequestService) echo.HandlerFunc {
	return func(c echo.Context) error {
		uid, ok := GetUserID(c)
		if !ok { return c.JSON(http.StatusUnauthorized, echo.Map{"error": "unauthorized"}) }
		gid, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": "invalid group id"}) }
		reqID, err := strconv.ParseInt(c.Param("req_id"), 10, 64)
		if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": "invalid request id"}) }
		if err := s.Decline(c.Request().Context(), gid, uid, reqID); err != nil {
			return c.JSON(http.StatusBadRequest, echo.Map{"error": err.Error()})
		}
		return c.NoContent(http.StatusNoContent)
	}
}
