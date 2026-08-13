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
	"github.com/worldbank/ai-coach/backend/internal/services/googledrive"
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

	// Initialize Google Drive service (optional)
	var driveService *googledrive.DriveService
	if cfg.GoogleServiceAccountKeyPath != "" && cfg.GoogleDriveFolderID != "" {
		driveService, err = googledrive.NewDriveService(cfg.GoogleServiceAccountKeyPath, cfg.GoogleDriveFolderID)
		if err != nil {
			log.Printf("Warning: Failed to initialize Google Drive service: %v", err)
			log.Printf("Recordings will only be saved to S3")
		} else {
			log.Println("Google Drive service initialized successfully")
		}
	} else {
		log.Println("Google Drive not configured, recordings will only be saved to S3")
	}

	// Initialize repository
	repo := repository.NewRepository(db.DB)

	// Promote the configured bootstrap user to admin (for the monitoring dashboard).
	if cfg.AdminBootstrapEmail != "" {
		if n, err := repo.PromoteUserToAdminByEmail(context.Background(), cfg.AdminBootstrapEmail); err != nil {
			log.Printf("Warning: failed to promote admin user %s: %v", cfg.AdminBootstrapEmail, err)
		} else if n > 0 {
			log.Printf("Promoted user %s to admin role", cfg.AdminBootstrapEmail)
		} else {
			log.Printf("Admin bootstrap: no user with email %s yet (promote will apply once they register)", cfg.AdminBootstrapEmail)
		}
	}

	// Initialize handlers
	authHandler := handlers.NewAuthHandler(repo, cfg.JWTSecret)
	recordingHandler := handlers.NewRecordingHandler(repo, s3Service, driveService)
	analysisHandler := handlers.NewAnalysisHandler(repo, geminiService, s3Service, driveService)
	chatHandler := handlers.NewChatHandler(repo, geminiService)
	progressHandler := handlers.NewProgressHandler(repo)
	adminHandler := handlers.NewAdminHandler(repo, s3Service)
	coachHandler := handlers.NewCoachHandler(repo, geminiService)

	// Set up Gin router
	gin.SetMode(cfg.GinMode)
	router := gin.Default()
	// Allow up to 200MB audio uploads in memory before spilling to disk
	router.MaxMultipartMemory = 200 << 20 // 200 MiB

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
		auth.POST("/verify-email", authHandler.VerifyEmail)
		auth.POST("/resend-verification", authHandler.ResendVerification)
		auth.POST("/forgot-password", authHandler.ForgotPassword)
		auth.POST("/reset-password", authHandler.ResetPassword)
	}

	// Protected routes
	authMiddleware := middleware.AuthMiddleware(cfg.JWTSecret)

	authProtected := router.Group("/api/v1/auth")
	authProtected.Use(authMiddleware)
	{
		authProtected.GET("/me", authHandler.GetMe)
		authProtected.PUT("/me", authHandler.UpdateMe)
		authProtected.POST("/change-password", authHandler.ChangePassword)
	}

	recordings := router.Group("/api/v1/recordings")
	recordings.Use(authMiddleware)
	{
		recordings.POST("", recordingHandler.Upload)
		recordings.GET("", recordingHandler.List)
		recordings.GET("/:id", recordingHandler.Get)
		recordings.GET("/:id/audio", recordingHandler.Stream)
		recordings.DELETE("/:id", recordingHandler.Delete)
		recordings.POST("/:id/analyze", analysisHandler.Analyze)

		// Coordinator flow: seven-block coaching conversation per TEACH element.
		// Owned by the same user as the recording, so no extra role gate.
		recordings.GET("/:id/coach-scripts", coachHandler.ListCoachScripts)
		recordings.GET("/:id/coach-script", coachHandler.GetCoachScript)
		recordings.POST("/:id/coach-script", coachHandler.GenerateCoachScript)
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
		chat.GET("/sessions", chatHandler.ListSessions) // Order matters if checking /:id
		chat.GET("/sessions/:id", chatHandler.GetSession)
		chat.DELETE("/sessions/:id", chatHandler.DeleteSession)
		chat.POST("/sessions/:id/messages", chatHandler.SendMessage)
		chat.POST("/sessions/:id/stream", chatHandler.StreamMessage)
	}

	progress := router.Group("/api/v1/progress")
	progress.Use(authMiddleware)
	{
		progress.GET("", progressHandler.GetProgress)
		progress.GET("/trends", progressHandler.GetTrends)
	}

	// Admin / monitoring dashboard routes (World Bank). Role-gated.
	// Read endpoints allow "admin" and "viewer"; user-management endpoints
	// allow "admin" only.
	dashboardAccess := middleware.RequireRoles(cfg.JWTSecret, repo, "admin", "viewer")
	adminOnly := middleware.RequireRoles(cfg.JWTSecret, repo, "admin")

	dashboard := router.Group("/api/v1/admin")
	dashboard.Use(dashboardAccess)
	{
		dashboard.GET("/overview", adminHandler.Overview)
		dashboard.GET("/lessons", adminHandler.Lessons)
		dashboard.GET("/lessons/:id", adminHandler.LessonDetail)
		dashboard.GET("/lessons/:id/audio", adminHandler.LessonAudio)
		// Manual scoring: coaches (admin|viewer) read/write their own score and
		// download a per-lesson workbook pre-filled with it.
		dashboard.GET("/lessons/:id/manual-score", adminHandler.GetManualScore)
		dashboard.PUT("/lessons/:id/manual-score", adminHandler.SaveManualScore)
		dashboard.GET("/lessons/:id/export", adminHandler.ExportLessonAnalysis)
		dashboard.GET("/usage", adminHandler.Usage)
		dashboard.GET("/teachers", adminHandler.Teachers)
		dashboard.GET("/filters", adminHandler.FilterOptions)
		dashboard.GET("/export", adminHandler.Export)
	}

	adminMgmt := router.Group("/api/v1/admin")
	adminMgmt.Use(adminOnly)
	{
		adminMgmt.GET("/users", adminHandler.Users)
		adminMgmt.PUT("/users/:id/role", adminHandler.UpdateUserRole)
	}

	// Create HTTP server with generous timeouts for large audio uploads
	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      router,
		ReadTimeout:  5 * time.Minute,  // allow up to 5min for large file uploads
		WriteTimeout: 10 * time.Minute, // analysis can take a few minutes
		IdleTimeout:  120 * time.Second,
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
