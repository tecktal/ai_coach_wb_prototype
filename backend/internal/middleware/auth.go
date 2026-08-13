package middleware

import (
	"fmt"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/worldbank/ai-coach/backend/internal/repository"
)

type Claims struct {
	UserID   uuid.UUID `json:"user_id"`
	Username string    `json:"username"`
	Email    string    `json:"email"`
	jwt.RegisteredClaims
}

// extractToken pulls the JWT from the Authorization header, falling back to the
// `token` query parameter (used for audio streaming).
func extractToken(c *gin.Context) string {
	authHeader := c.GetHeader("Authorization")
	if authHeader != "" {
		parts := strings.Split(authHeader, " ")
		if len(parts) == 2 && parts[0] == "Bearer" {
			return parts[1]
		}
	}
	return c.Query("token")
}

// parseToken validates the JWT string and returns its claims.
func parseToken(tokenString, jwtSecret string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return []byte(jwtSecret), nil
	})
	if err != nil {
		return nil, err
	}
	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, fmt.Errorf("invalid token claims")
	}
	return claims, nil
}

// authenticate runs the shared extract+parse flow and stores the user info in
// the gin context. It returns the claims so callers (e.g. AdminMiddleware) can
// perform additional authorization checks. On failure it writes the response,
// aborts the context, and returns ok=false.
func authenticate(c *gin.Context, jwtSecret string) (*Claims, bool) {
	tokenString := extractToken(c)
	if tokenString == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization required"})
		c.Abort()
		return nil, false
	}

	claims, err := parseToken(tokenString, jwtSecret)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
		c.Abort()
		return nil, false
	}

	c.Set("user_id", claims.UserID)
	c.Set("user_email", claims.Email)
	return claims, true
}

func AuthMiddleware(jwtSecret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		if _, ok := authenticate(c, jwtSecret); !ok {
			return
		}
		c.Next()
	}
}

// RequireRoles authenticates the request and then verifies the user's role is
// one of the allowed roles by looking them up in the database. The role is
// intentionally not carried in the JWT, so existing tokens never gain elevated
// access and no re-login is required when a user's role changes.
//
// Used for the monitoring dashboard: read endpoints allow "admin" and "viewer";
// user-management endpoints allow "admin" only.
func RequireRoles(jwtSecret string, repo *repository.Repository, allowed ...string) gin.HandlerFunc {
	allowedSet := make(map[string]bool, len(allowed))
	for _, r := range allowed {
		allowedSet[r] = true
	}
	return func(c *gin.Context) {
		claims, ok := authenticate(c, jwtSecret)
		if !ok {
			return
		}

		user, err := repo.GetUserByID(c.Request.Context(), claims.UserID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to verify permissions"})
			c.Abort()
			return
		}
		if user == nil || !allowedSet[user.Role] {
			c.JSON(http.StatusForbidden, gin.H{"error": "You do not have access to this resource"})
			c.Abort()
			return
		}

		c.Next()
	}
}

// GetUserID extracts user ID from context
func GetUserID(c *gin.Context) (uuid.UUID, error) {
	userID, exists := c.Get("user_id")
	if !exists {
		return uuid.Nil, fmt.Errorf("user_id not found in context")
	}
	return userID.(uuid.UUID), nil
}
