package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/worldbank/ai-coach/backend/internal/config"
	"github.com/worldbank/ai-coach/backend/internal/database"
	"github.com/worldbank/ai-coach/backend/internal/handlers"
	"github.com/worldbank/ai-coach/backend/internal/middleware"
	"github.com/worldbank/ai-coach/backend/internal/repository"
	"github.com/worldbank/ai-coach/backend/internal/services/gemini"
	"github.com/worldbank/ai-coach/backend/internal/services/storage"
)

func main() {
	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Connect to database
	db, err := database.Connect(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	// Run migrations
	if err := db.RunMigrations(); err != nil {
		log.Fatalf("Failed to run migrations: %v", err)
	}

	// Initialize services
	geminiService, err := gemini.NewGeminiService(cfg.GeminiAPIKey)
	if err != nil {
		log.Fatalf("Failed to initialize Gemini service: %v", err)
	}
	defer geminiService.Close()

	s3Service, err := storage.NewS3Service(
		cfg.S3Endpoint,
		cfg.S3Bucket,
		cfg.S3AccessKey,
		cfg.S3SecretKey,
		cfg.S3Region,
		cfg.S3UseSSL,
	)
	if err != nil {
		log.Fatalf("Failed to initialize S3 service: %v", err)
	}

	// Initialize repository
	repo := repository.NewRepository(db.DB)

	// Initialize handlers
	authHandler := handlers.NewAuthHandler(repo, cfg.JWTSecret)
	recordingHandler := handlers.NewRecordingHandler(repo, s3Service)
	analysisHandler := handlers.NewAnalysisHandler(repo, geminiService, s3Service)
	chatHandler := handlers.NewChatHandler(repo, geminiService)
	progressHandler := handlers.NewProgressHandler(repo)

	// Set up Gin router
	gin.SetMode(cfg.GinMode)
	router := gin.Default()

	// CORS configuration
	corsConfig := cors.Config{
		// Allow any origin for development purposes
		AllowOriginFunc: func(origin string) bool {
			return true
		},
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Accept", "Authorization", "X-Requested-With"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
	}
	router.Use(cors.New(corsConfig))

	// Health check
	router.GET("/api/v1/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status": "healthy",
			"time":   time.Now().Format(time.RFC3339),
		})
	})

	// Public routes
	auth := router.Group("/api/v1/auth")
	{
		auth.POST("/register", authHandler.Register)
		auth.POST("/login", authHandler.Login)
	}

	// Protected routes
	authMiddleware := middleware.AuthMiddleware(cfg.JWTSecret)

	authProtected := router.Group("/api/v1/auth")
	authProtected.Use(authMiddleware)
	{
		authProtected.GET("/me", authHandler.GetMe)
		authProtected.PUT("/me", authHandler.UpdateMe)
	}

	recordings := router.Group("/api/v1/recordings")
	recordings.Use(authMiddleware)
	{
		recordings.POST("", recordingHandler.Upload)
		recordings.GET("", recordingHandler.List)
		recordings.GET("/:id", recordingHandler.Get)
		recordings.DELETE("/:id", recordingHandler.Delete)
		recordings.POST("/:id/analyze", analysisHandler.Analyze)
	}

	analyses := router.Group("/api/v1/analyses")
	analyses.Use(authMiddleware)
	{
		analyses.GET("", analysisHandler.List)
		analyses.GET("/:id", analysisHandler.Get)
	}

	chat := router.Group("/api/v1/chat")
	chat.Use(authMiddleware)
	{
		chat.POST("/sessions", chatHandler.CreateSession)
		chat.GET("/sessions/:id", chatHandler.GetSession)
		chat.POST("/sessions/:id/messages", chatHandler.SendMessage)
	}

	progress := router.Group("/api/v1/progress")
	progress.Use(authMiddleware)
	{
		progress.GET("", progressHandler.GetProgress)
		progress.GET("/trends", progressHandler.GetTrends)
	}

	// Create HTTP server
	srv := &http.Server{
		Addr:    ":" + cfg.Port,
		Handler: router,
	}

	// Start server in goroutine
	go func() {
		log.Printf("Starting server on port %s", cfg.Port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to start server: %v", err)
		}
	}()

	// Wait for interrupt signal to gracefully shutdown the server
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down server...")

	// Graceful shutdown with 5 second timeout
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatal("Server forced to shutdown:", err)
	}

	log.Println("Server exited")
}
