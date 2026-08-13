package handlers

import (
	"fmt"
	"math/rand"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/worldbank/ai-coach/backend/internal/middleware"
	"github.com/worldbank/ai-coach/backend/internal/models"
	"github.com/worldbank/ai-coach/backend/internal/repository"
	"github.com/worldbank/ai-coach/backend/internal/services/email"
	"github.com/worldbank/ai-coach/backend/internal/services/gemini"
	"golang.org/x/crypto/bcrypt"
)

type AuthHandler struct {
	repo      *repository.Repository
	jwtSecret string
}

func NewAuthHandler(repo *repository.Repository, jwtSecret string) *AuthHandler {
	return &AuthHandler{
		repo:      repo,
		jwtSecret: jwtSecret,
	}
}

func (h *AuthHandler) Register(c *gin.Context) {
	var req models.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: err.Error()})
		return
	}

	// Check if username already exists
	existingUser, err := h.repo.GetUserByUsername(c.Request.Context(), req.Username)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to check existing user"})
		return
	}
	if existingUser != nil {
		c.JSON(http.StatusConflict, models.ErrorResponse{Error: "User with this username already exists"})
		return
	}

	// Also check if email exists (if provided)
	if req.Email != nil && *req.Email != "" {
		existingEmail, err := h.repo.GetUserByEmail(c.Request.Context(), *req.Email)
		if err != nil {
			// A real DB error (e.g. missing column, connection issue) — don't fall
			// through silently. Surface a 500 so the client gets a real status code
			// rather than a misleading network error.
			fmt.Printf("Register: GetUserByEmail error: %v\n", err)
			c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to validate email"})
			return
		}
		if existingEmail != nil {
			c.JSON(http.StatusConflict, models.ErrorResponse{Error: "User with this email already exists"})
			return
		}
	}

	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to hash password"})
		return
	}

	// Set default language if not provided
	if req.LanguagePreference == "" {
		req.LanguagePreference = "en"
	}

	// Self-declared role, restricted to teacher/coordinator. Anything else —
	// including "admin" and "viewer", which grant dashboard access — becomes
	// "teacher". Elevated roles are only ever granted by an existing admin
	// through PUT /api/v1/admin/users/:id/role.
	role := models.SelfAssignableRole(req.Role)

	// A coordinator reads feedback to lead a conversation rather than being its
	// subject, so the role seeds the audience. The user can still change it in
	// Profile afterwards — role is identity, audience is a preference.
	audience := gemini.AudienceTeacher
	if role == models.RoleCoordinator {
		audience = gemini.AudienceCoordinator
	}

	// Create user (email_verified defaults to false in database)
	user := &models.User{
		Username:           req.Username,
		Email:              req.Email,
		PasswordHash:       string(hashedPassword),
		FirstName:          req.FirstName,
		LastName:           req.LastName,
		Role:               role,
		SchoolName:         req.SchoolName,
		Country:            req.Country,
		LanguagePreference: req.LanguagePreference,
		FeedbackAudience:   audience,
		EmailVerified:      false,
	}

	if err := h.repo.CreateUser(c.Request.Context(), user); err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to create user"})
		return
	}

	if req.Email != nil && *req.Email != "" {
		// Generate cryptographically random 6-digit verification code
		verificationCode := fmt.Sprintf("%06d", rand.Intn(1000000))
		expiresAt := time.Now().Add(24 * time.Hour)

		// Save verification code.
		// NOTE: If this fails with "column does not exist", run the migration:
		//   ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verification_code VARCHAR(6);
		//   ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verification_code_expires_at TIMESTAMPTZ;
		if err := h.repo.SetEmailVerificationCode(c.Request.Context(), *user.Email, verificationCode, expiresAt); err != nil {
			// Log but don't fail registration — the user can request a resend later
			fmt.Printf("Register: SetEmailVerificationCode failed (check DB migration): %v\n", err)
		}

		// Send verification email (async, don't block registration)
		go func() {
			emailService := email.NewEmailService()
			if err := emailService.SendVerificationEmail(*user.Email, verificationCode); err != nil {
				fmt.Printf("Register: SendVerificationEmail failed: %v\n", err)
			}
		}()
	}

	// Generate JWT token
	token, err := h.generateToken(user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to generate token"})
		return
	}

	c.JSON(http.StatusCreated, models.LoginResponse{
		Token: token,
		User:  *user,
	})
}

func (h *AuthHandler) Login(c *gin.Context) {
	var req models.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: err.Error()})
		return
	}

	// Get user by username
	user, err := h.repo.GetUserByUsername(c.Request.Context(), req.Username)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to get user"})
		return
	}
	if user == nil {
		c.JSON(http.StatusUnauthorized, models.ErrorResponse{Error: "Invalid email or password"})
		return
	}

	// Verify password
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		c.JSON(http.StatusUnauthorized, models.ErrorResponse{Error: "Invalid email or password"})
		return
	}

	// Generate JWT token
	token, err := h.generateToken(user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to generate token"})
		return
	}

	c.JSON(http.StatusOK, models.LoginResponse{
		Token: token,
		User:  *user,
	})
}

func (h *AuthHandler) GetMe(c *gin.Context) {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, models.ErrorResponse{Error: "Unauthorized"})
		return
	}

	user, err := h.repo.GetUserByID(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to get user"})
		return
	}
	if user == nil {
		c.JSON(http.StatusNotFound, models.ErrorResponse{Error: "User not found"})
		return
	}

	c.JSON(http.StatusOK, user)
}

func (h *AuthHandler) UpdateMe(c *gin.Context) {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, models.ErrorResponse{Error: "Unauthorized"})
		return
	}

	var req models.UpdateProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: err.Error()})
		return
	}

	// Get current user
	user, err := h.repo.GetUserByID(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to get user"})
		return
	}
	if user == nil {
		c.JSON(http.StatusNotFound, models.ErrorResponse{Error: "User not found"})
		return
	}

	// Update fields
	if req.FirstName != nil {
		user.FirstName = *req.FirstName
	}
	if req.LastName != nil {
		user.LastName = *req.LastName
	}
	if req.Email != nil && (user.Email == nil || *req.Email != *user.Email) {
		user.Email = req.Email
		user.EmailVerified = false
	}
	if req.SchoolName != nil {
		user.SchoolName = req.SchoolName
	}
	if req.Country != nil {
		user.Country = req.Country
	}
	if req.LanguagePreference != nil {
		user.LanguagePreference = *req.LanguagePreference
	}
	if req.FeedbackAudience != nil {
		// Reject unknown values rather than letting them reach a prompt.
		if *req.FeedbackAudience != gemini.AudienceTeacher &&
			*req.FeedbackAudience != gemini.AudienceCoordinator {
			c.JSON(http.StatusBadRequest, models.ErrorResponse{
				Error: "Invalid feedback_audience. Must be 'teacher' or 'coordinator'.",
			})
			return
		}
		user.FeedbackAudience = *req.FeedbackAudience
	}

	if err := h.repo.UpdateUser(c.Request.Context(), user); err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to update user"})
		return
	}

	c.JSON(http.StatusOK, user)
}

func (h *AuthHandler) generateToken(user *models.User) (string, error) {
	email := ""
	if user.Email != nil {
		email = *user.Email
	}

	claims := &middleware.Claims{
		UserID:   user.ID,
		Username: user.Username,
		Email:    email,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(30 * 24 * time.Hour)), // 30 days — login once per device
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(h.jwtSecret))
}

func (h *AuthHandler) VerifyEmail(c *gin.Context) {
	var req models.VerifyEmailRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: err.Error()})
		return
	}

	// Verify the code
	err := h.repo.VerifyEmail(c.Request.Context(), req.Email, req.Code)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: "Invalid or expired verification code"})
		return
	}

	c.JSON(http.StatusOK, models.SuccessResponse{Message: "Email verified successfully"})
}

func (h *AuthHandler) ResendVerification(c *gin.Context) {
	var req models.ResendVerificationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: err.Error()})
		return
	}

	// Check if user exists
	user, err := h.repo.GetUserByEmail(c.Request.Context(), req.Email)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to get user"})
		return
	}
	if user == nil {
		c.JSON(http.StatusNotFound, models.ErrorResponse{Error: "User not found"})
		return
	}

	// Check if already verified
	if user.EmailVerified {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: "Email already verified"})
		return
	}

	// Generate cryptographically random 6-digit verification code
	verificationCode := fmt.Sprintf("%06d", rand.Intn(1000000))
	expiresAt := time.Now().Add(24 * time.Hour)

	userEmail := ""
	if user.Email != nil {
		userEmail = *user.Email
	}

	// Save verification code
	if err := h.repo.SetEmailVerificationCode(c.Request.Context(), userEmail, verificationCode, expiresAt); err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to generate verification code"})
		return
	}

	// Send verification email (async)
	go func() {
		emailService := email.NewEmailService()
		if err := emailService.SendVerificationEmail(userEmail, verificationCode); err != nil {
			fmt.Printf("Failed to send verification email: %v\n", err)
		}
	}()

	c.JSON(http.StatusOK, models.SuccessResponse{Message: "Verification code sent"})
}

func (h *AuthHandler) ForgotPassword(c *gin.Context) {
	var req models.ForgotPasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: err.Error()})
		return
	}

	// Check if user exists
	user, err := h.repo.GetUserByEmail(c.Request.Context(), req.Email)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to process request"})
		return
	}

	// Always return success to prevent email enumeration
	if user == nil {
		c.JSON(http.StatusOK, models.SuccessResponse{Message: "If the email exists, a password reset link has been sent"})
		return
	}

	// Generate reset token (64 character random string)
	resetToken := fmt.Sprintf("%x", time.Now().UnixNano())
	expiresAt := time.Now().Add(1 * time.Hour)

	userEmail := ""
	if user.Email != nil {
		userEmail = *user.Email
	}

	// Save reset token
	if err := h.repo.SetPasswordResetToken(c.Request.Context(), userEmail, resetToken, expiresAt); err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to process request"})
		return
	}

	// Send reset email (async)
	go func() {
		emailService := email.NewEmailService()
		if err := emailService.SendPasswordResetEmail(userEmail, resetToken); err != nil {
			fmt.Printf("Failed to send password reset email: %v\n", err)
		}
	}()

	c.JSON(http.StatusOK, models.SuccessResponse{Message: "If the email exists, a password reset link has been sent"})
}

func (h *AuthHandler) ResetPassword(c *gin.Context) {
	var req models.ResetPasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: err.Error()})
		return
	}

	// Get user by reset token
	user, err := h.repo.GetUserByResetToken(c.Request.Context(), req.Token)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to process request"})
		return
	}
	if user == nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: "Invalid or expired reset token"})
		return
	}

	// Hash new password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to hash password"})
		return
	}

	// Update password
	if err := h.repo.UpdatePassword(c.Request.Context(), user.ID, string(hashedPassword)); err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to update password"})
		return
	}

	c.JSON(http.StatusOK, models.SuccessResponse{Message: "Password reset successfully"})
}

func (h *AuthHandler) ChangePassword(c *gin.Context) {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, models.ErrorResponse{Error: "Unauthorized"})
		return
	}

	var req struct {
		CurrentPassword string `json:"current_password" binding:"required"`
		NewPassword     string `json:"new_password"     binding:"required,min=6"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: err.Error()})
		return
	}

	// Fetch user
	user, err := h.repo.GetUserByID(c.Request.Context(), userID)
	if err != nil || user == nil {
		c.JSON(http.StatusNotFound, models.ErrorResponse{Error: "User not found"})
		return
	}

	// Verify current password
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.CurrentPassword)); err != nil {
		c.JSON(http.StatusUnauthorized, models.ErrorResponse{Error: "Current password is incorrect"})
		return
	}

	// Hash new password
	hashed, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to hash password"})
		return
	}

	// Save to DB
	if err := h.repo.UpdatePassword(c.Request.Context(), userID, string(hashed)); err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to update password"})
		return
	}

	c.JSON(http.StatusOK, models.SuccessResponse{Message: "Password changed successfully"})
}

