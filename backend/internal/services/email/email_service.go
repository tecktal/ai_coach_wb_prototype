package email

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
)

type EmailService struct {
	apiKey string
	from   string
}

type ResendEmailRequest struct {
	From    string   `json:"from"`
	To      []string `json:"to"`
	Subject string   `json:"subject"`
	HTML    string   `json:"html"`
}

func NewEmailService() *EmailService {
	apiKey := os.Getenv("RESEND_API_KEY")
	from := os.Getenv("RESEND_FROM_EMAIL")

	if from == "" {
		from = "AI Teaching Coach <noreply@aicoach.app>"
	}

	return &EmailService{
		apiKey: apiKey,
		from:   from,
	}
}

func (s *EmailService) SendVerificationEmail(to, code string) error {
	subject := "Verify Your Email - AI Teaching Coach"
	html := fmt.Sprintf(`
		<!DOCTYPE html>
		<html>
		<head>
			<style>
				body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
				.container { max-width: 600px; margin: 0 auto; padding: 20px; }
				.header { background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
				.content { background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }
				.code { font-size: 32px; font-weight: bold; color: #667eea; text-align: center; letter-spacing: 8px; margin: 20px 0; padding: 20px; background: white; border-radius: 8px; }
				.footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
			</style>
		</head>
		<body>
			<div class="container">
				<div class="header">
					<h1>Welcome to AI Teaching Coach!</h1>
				</div>
				<div class="content">
					<p>Thank you for registering. Please verify your email address to get started.</p>
					<p>Your verification code is:</p>
					<div class="code">%s</div>
					<p>This code will expire in 24 hours.</p>
					<p>If you didn't create an account, you can safely ignore this email.</p>
				</div>
				<div class="footer">
					<p>© 2026 AI Teaching Coach. All rights reserved.</p>
				</div>
			</div>
		</body>
		</html>
	`, code)

	return s.sendEmail(to, subject, html)
}

func (s *EmailService) SendPasswordResetEmail(to, token string) error {
	subject := "Reset Your Password - AI Teaching Coach"
	resetURL := fmt.Sprintf("https://aicoach.app/reset-password?token=%s", token)

	html := fmt.Sprintf(`
		<!DOCTYPE html>
		<html>
		<head>
			<style>
				body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
				.container { max-width: 600px; margin: 0 auto; padding: 20px; }
				.header { background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
				.content { background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }
				.button { display: inline-block; padding: 15px 30px; background: #667eea; color: white; text-decoration: none; border-radius: 5px; margin: 20px 0; }
				.footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
			</style>
		</head>
		<body>
			<div class="container">
				<div class="header">
					<h1>Password Reset Request</h1>
				</div>
				<div class="content">
					<p>We received a request to reset your password for your AI Teaching Coach account.</p>
					<p>Click the button below to reset your password:</p>
					<p style="text-align: center;">
						<a href="%s" class="button">Reset Password</a>
					</p>
					<p>Or copy and paste this link into your browser:</p>
					<p style="word-break: break-all; color: #667eea;">%s</p>
					<p>This link will expire in 1 hour.</p>
					<p>If you didn't request a password reset, you can safely ignore this email.</p>
				</div>
				<div class="footer">
					<p>© 2026 AI Teaching Coach. All rights reserved.</p>
				</div>
			</div>
		</body>
		</html>
	`, resetURL, resetURL)

	return s.sendEmail(to, subject, html)
}

func (s *EmailService) sendEmail(to, subject, html string) error {
	// If no API key configured, log to console (development mode)
	if s.apiKey == "" {
		fmt.Printf("\n=== EMAIL (Development Mode) ===\n")
		fmt.Printf("To: %s\n", to)
		fmt.Printf("Subject: %s\n", subject)
		fmt.Printf("HTML: %s\n", html)
		fmt.Printf("================================\n\n")
		return nil
	}

	// Send via Resend API
	reqBody := ResendEmailRequest{
		From:    s.from,
		To:      []string{to},
		Subject: subject,
		HTML:    html,
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return fmt.Errorf("failed to marshal email request: %w", err)
	}

	req, err := http.NewRequest("POST", "https://api.resend.com/emails", bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+s.apiKey)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to send email: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("email API returned status %d: %s", resp.StatusCode, string(body))
	}

	return nil
}
