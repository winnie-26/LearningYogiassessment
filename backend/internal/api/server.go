package api

import (
	"net/http"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	"github.com/jmoiron/sqlx"
	"github.com/rs/zerolog"
	"golang.org/x/time/rate"
	"secure-messaging-backend/internal/config"
	"secure-messaging-backend/internal/service"
	"secure-messaging-backend/internal/store"
)

type ServerDeps struct {
	Cfg *config.Config
	Log zerolog.Logger
	DB  *sqlx.DB
}

func NewServer(cfg *config.Config, log zerolog.Logger, db *sqlx.DB) *echo.Echo {
	e := echo.New()
	e.HideBanner = true
	e.Use(middleware.Recover())
	e.Use(middleware.RequestID())
	e.Use(middleware.Secure())
	e.Use(middleware.CORS())

	// Simple health
	e.GET("/healthz", func(c echo.Context) error { return c.String(http.StatusOK, "ok") })

	// Build stores/services
	userStore := store.NewUserStore(db)
	authSvc := service.NewAuthService(cfg, userStore)
	groupStore := store.NewGroupStore(db)
	groupSvc := service.NewGroupService(groupStore, userStore, cfg.MasterKey)
	joinSvc := service.NewJoinRequestService(groupStore)
	msgStore := store.NewMessageStore(db)
	msgSvc := service.NewMessageService(cfg, groupStore, msgStore, log)

	// API routes under /api/v1
	v1 := e.Group("/api/v1")

	// Auth
	auth := v1.Group("/auth")
	// naive rate limit: convert per-minute to per-second
	perSec := rate.Limit(float64(cfg.RateLimitPerMinute) / 60.0)
	if perSec < 1 {
		perSec = 1
	}
	auth.Use(middleware.RateLimiter(middleware.NewRateLimiterMemoryStore(perSec)))
	auth.POST("/register", RegisterHandler(authSvc))
	auth.POST("/login", LoginHandler(authSvc))
	auth.POST("/refresh", RefreshHandler(authSvc))

	// Groups: GET is public (lists public + owned when auth provided)
	v1.GET("/groups", ListGroupsHandler(groupSvc))
	// Other group operations require auth
	grp := v1.Group("/groups")
	grp.Use(JWTMiddleware(cfg.JWTAccessSecret))
	grp.POST("", CreateGroupHandler(groupSvc))
	grp.POST("/:id/join", JoinGroupHandler(groupSvc))
	grp.POST("/:id/leave", LeaveGroupHandler(groupSvc))
	grp.POST("/:id/transfer-owner", TransferOwnerHandler(groupSvc))
	grp.DELETE("/:id", DeleteGroupHandler(groupSvc))
	grp.POST("/:id/banish", BanishHandler(groupSvc))

	// Join Requests (owner only actions)
	grp.GET("/:id/join-requests", ListJoinRequestsHandler(joinSvc))
	grp.POST("/:id/join-requests/:req_id/approve", ApproveJoinRequestHandler(joinSvc))
	grp.POST("/:id/join-requests/:req_id/decline", DeclineJoinRequestHandler(joinSvc))

	// Messaging
	grp.POST("/:id/messages", SendMessageHandler(msgSvc))
	grp.GET("/:id/messages", ListMessagesHandler(msgSvc))

	// Swagger placeholder
	e.GET("/swagger", func(c echo.Context) error {
		return c.JSON(http.StatusOK, map[string]string{"docs": "/openapi/openapi.yaml"})
	})

	return e
}
