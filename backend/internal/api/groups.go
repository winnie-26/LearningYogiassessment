package api

import (
	"net/http"
	"strconv"

	"github.com/labstack/echo/v4"
	"secure-messaging-backend/internal/service"
)

type createGroupReq struct {
	Name       string `json:"name"`
	Type       string `json:"type"`
	MaxMembers int    `json:"max_members"`
}

type transferOwnerReq struct {
	NewOwnerID int64 `json:"new_owner_id"`
}

type banishReq struct {
	UserID int64   `json:"user_id"`
	Reason *string `json:"reason"`
}

func CreateGroupHandler(s *service.GroupService) echo.HandlerFunc {
	return func(c echo.Context) error {
		uid, ok := GetUserID(c)
		if !ok { return c.JSON(http.StatusUnauthorized, echo.Map{"error": "unauthorized"}) }
		req := new(createGroupReq)
		if err := c.Bind(req); err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": "invalid body"}) }
		g, err := s.CreateGroup(c.Request().Context(), req.Name, uid, req.Type, req.MaxMembers)
		if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": err.Error()}) }
		return c.JSON(http.StatusCreated, echo.Map{"id": g.ID, "name": g.Name, "owner_id": g.OwnerID, "type": g.Type, "max_members": g.MaxMembers})
	}
}

func ListGroupsHandler(s *service.GroupService) echo.HandlerFunc {
	return func(c echo.Context) error {
		limitStr := c.QueryParam("limit")
		limit := 50
		if limitStr != "" {
			if v, err := strconv.Atoi(limitStr); err == nil { limit = v }
		}
		pub, err := s.ListPublic(c.Request().Context(), limit)
		if err != nil { return c.JSON(http.StatusInternalServerError, echo.Map{"error": err.Error()}) }
		uid, _ := GetUserID(c)
		owned := []interface{}{}
		if uid != 0 {
			ogs, err := s.ListOwned(c.Request().Context(), uid)
			if err == nil {
				for _, g := range ogs {
					owned = append(owned, echo.Map{"id": g.ID, "name": g.Name, "type": g.Type, "max_members": g.MaxMembers})
				}
			}
		}
		pubOut := []interface{}{}
		for _, g := range pub {
			pubOut = append(pubOut, echo.Map{"id": g.ID, "name": g.Name, "type": g.Type, "max_members": g.MaxMembers})
		}
		return c.JSON(http.StatusOK, echo.Map{"public": pubOut, "owned": owned})
	}
}

func JoinGroupHandler(s *service.GroupService) echo.HandlerFunc {
	return func(c echo.Context) error {
		uid, ok := GetUserID(c)
		if !ok { return c.JSON(http.StatusUnauthorized, echo.Map{"error": "unauthorized"}) }
		gidStr := c.Param("id")
		gid, err := strconv.ParseInt(gidStr, 10, 64)
		if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": "invalid group id"}) }
		status, err := s.Join(c.Request().Context(), gid, uid)
		if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": err.Error()}) }
		return c.JSON(http.StatusOK, echo.Map{"status": status})
	}
}

func LeaveGroupHandler(s *service.GroupService) echo.HandlerFunc {
	return func(c echo.Context) error {
		uid, ok := GetUserID(c)
		if !ok { return c.JSON(http.StatusUnauthorized, echo.Map{"error": "unauthorized"}) }
		gidStr := c.Param("id")
		gid, err := strconv.ParseInt(gidStr, 10, 64)
		if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": "invalid group id"}) }
		if err := s.Leave(c.Request().Context(), gid, uid); err != nil {
			return c.JSON(http.StatusBadRequest, echo.Map{"error": err.Error()})
		}
		return c.NoContent(http.StatusNoContent)
	}
}

func TransferOwnerHandler(s *service.GroupService) echo.HandlerFunc {
	return func(c echo.Context) error {
		uid, ok := GetUserID(c)
		if !ok { return c.JSON(http.StatusUnauthorized, echo.Map{"error": "unauthorized"}) }
		gidStr := c.Param("id")
		gid, err := strconv.ParseInt(gidStr, 10, 64)
		if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": "invalid group id"}) }
		req := new(transferOwnerReq)
		if err := c.Bind(req); err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": "invalid body"}) }
		if err := s.TransferOwner(c.Request().Context(), gid, uid, req.NewOwnerID); err != nil {
			return c.JSON(http.StatusBadRequest, echo.Map{"error": err.Error()})
		}
		return c.NoContent(http.StatusNoContent)
	}
}

func DeleteGroupHandler(s *service.GroupService) echo.HandlerFunc {
	return func(c echo.Context) error {
		uid, ok := GetUserID(c)
		if !ok { return c.JSON(http.StatusUnauthorized, echo.Map{"error": "unauthorized"}) }
		gidStr := c.Param("id")
		gid, err := strconv.ParseInt(gidStr, 10, 64)
		if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": "invalid group id"}) }
		if err := s.Delete(c.Request().Context(), gid, uid); err != nil {
			return c.JSON(http.StatusBadRequest, echo.Map{"error": err.Error()})
		}
		return c.NoContent(http.StatusNoContent)
	}
}

func BanishHandler(s *service.GroupService) echo.HandlerFunc {
	return func(c echo.Context) error {
		uid, ok := GetUserID(c)
		if !ok { return c.JSON(http.StatusUnauthorized, echo.Map{"error": "unauthorized"}) }
		gidStr := c.Param("id")
		gid, err := strconv.ParseInt(gidStr, 10, 64)
		if err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": "invalid group id"}) }
		req := new(banishReq)
		if err := c.Bind(req); err != nil { return c.JSON(http.StatusBadRequest, echo.Map{"error": "invalid body"}) }
		if req.UserID == 0 { return c.JSON(http.StatusBadRequest, echo.Map{"error": "user_id required"}) }
		if err := s.Banish(c.Request().Context(), gid, uid, req.UserID, req.Reason); err != nil {
			return c.JSON(http.StatusBadRequest, echo.Map{"error": err.Error()})
		}
		return c.NoContent(http.StatusNoContent)
	}
}
