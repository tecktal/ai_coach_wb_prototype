package gemini

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"google.golang.org/genai"
)

type GeminiService struct {
	client *genai.Client
	apiKey string
}

func NewGeminiService(apiKey string) (*GeminiService, error) {
	if apiKey == "" {
		return nil, fmt.Errorf("Gemini API key is required")
	}

	ctx := context.Background()
	client, err := genai.NewClient(ctx, &genai.ClientConfig{
		APIKey: apiKey,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create Gemini client: %w", err)
	}

	return &GeminiService{
		client: client,
		apiKey: apiKey,
	}, nil
}

func (s *GeminiService) Close() error {
	// genai.Client doesn't strictly require a Close() method in v0.5.0 but good for interface compat
	return nil // client.Close() if available
}

// AnalyzeRecording performs combined transcription + TEACH analysis
func (s *GeminiService) AnalyzeRecording(ctx context.Context, audioPath string) (*TEACHAnalysisResult, error) {
	// 1. Read file for Inline Data (files < 20MB support inline)
	audioData, err := os.ReadFile(audioPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read audio file: %w", err)
	}

	// Detect MIME type (simple extension check)
	mimeType := "audio/m4a" // Default for our app
	ext := strings.ToLower(filepath.Ext(audioPath))
	if ext == ".mp3" {
		mimeType = "audio/mp3"
	} else if ext == ".wav" {
		mimeType = "audio/wav"
	}

	// 2. Prepare the prompt using enhanced TEACH documentation
	// We combine the specific task prompt with the full reference context
	taskPrompt := s.GetTEACHAnalysisPrompt()
	referenceContext := GetTEACHFrameworkContext()

	// We append the reference context as a secondary part (or system instruction if preferred, but here combining text avoids context window issues on some models)
	fullPrompt := taskPrompt + "\n\n=== REFERENCE FRAMEWORK ===\n" + referenceContext

	// 3. Generate Content
	parts := []*genai.Part{
		{InlineData: &genai.Blob{MIMEType: mimeType, Data: audioData}},
		{Text: fullPrompt},
	}

	temperature := float32(0.2) // Low temperature for consistent, strict analysis

	// Retry logic for 503 Overloaded errors
	var resp *genai.GenerateContentResponse

	maxRetries := 3
	maxTokens := int32(8192)
	for i := 0; i < maxRetries; i++ {
		resp, err = s.client.Models.GenerateContent(
			ctx,
			"gemini-2.5-flash",
			[]*genai.Content{{Parts: parts, Role: "user"}},
			&genai.GenerateContentConfig{
				Temperature:      &temperature,
				ResponseMIMEType: "application/json",
				MaxOutputTokens:  &maxTokens,
			},
		)

		if err == nil {
			break
		}

		// Check if error is 503/Overloaded OR 429/ResourceExhausted
		errStr := strings.ToLower(err.Error())
		if strings.Contains(errStr, "503") || strings.Contains(errStr, "overloaded") ||
			strings.Contains(errStr, "429") || strings.Contains(errStr, "resource exhausted") || strings.Contains(errStr, "quota") {

			if i < maxRetries-1 {
				// Exponential backoff: 2s, 4s, 8s
				backoff := time.Duration(1<<i) * 2 * time.Second
				fmt.Printf("Gemini Busy/Rate Limit (%s). Retrying in %v...\n", err, backoff)
				time.Sleep(backoff)
				continue
			}
		}

		// If other error or max retries reached
		return nil, fmt.Errorf("gemini generation failed: %w", err)
	}

	if len(resp.Candidates) == 0 || len(resp.Candidates[0].Content.Parts) == 0 {
		return nil, fmt.Errorf("empty response from Gemini")
	}

	// 4. Parse the response
	jsonText := ""
	for _, part := range resp.Candidates[0].Content.Parts {
		if part.Text != "" {
			jsonText += part.Text
		}
	}

	extractedJSON := extractJSON(jsonText)
	var result TEACHAnalysisResult
	if err := json.Unmarshal([]byte(extractedJSON), &result); err != nil {
		return nil, fmt.Errorf("failed to parse JSON response: %w - Text: %s", err, extractedJSON)
	}

	// Check if analysis seems valid (has a score)
	if result.OverallScore == 0 {
		return nil, fmt.Errorf("parsed result has no score, analysis likely failed")
	}

	// Set placeholder for transcription since we requested to omit it
	if result.Transcription.FullText == "" {
		result.Transcription.FullText = "[Transcription omitted to optimize analysis speed and reliability]"
	}

	return &result, nil
}

// GetCoachingResponse generates a coaching chat response
func (s *GeminiService) GetCoachingResponse(ctx context.Context, conversationHistory []map[string]string, analysisContext string) (string, error) {
	// Build parts from history
	var contents []*genai.Content

	// Add system instruction as first part of the conversation or as a SystemInstruction config if supported.
	// genai.GenerateContentConfig has SystemInstruction.

	systemPrompt := `You are an AI teaching coach helping a teacher improve based on their TEACH analysis.
Your role:
- Answer questions about their lesson analysis
- Provide specific, actionable teaching strategies
- Give concrete examples they can use tomorrow
- Be supportive and encouraging while being honest
- Keep responses under 300 words
Reference specific evidence from their lesson when giving advice.`

	// Add context to the first user message if history is empty, or use SystemInstruction.
	// We'll use SystemInstruction for the persona and context.

	fullSystemPrompt := systemPrompt + "\n\nContext from their recent lesson:\n" + analysisContext

	for _, msg := range conversationHistory {
		role := "user"
		if msg["role"] == "assistant" {
			role = "model"
		}
		contents = append(contents, &genai.Content{
			Role: role,
			Parts: []*genai.Part{
				{Text: msg["content"]},
			},
		})
	}

	temperature := float32(0.7)
	resp, err := s.client.Models.GenerateContent(
		ctx,
		"gemini-1.5-flash-001",
		contents,
		&genai.GenerateContentConfig{
			Temperature:       &temperature,
			SystemInstruction: &genai.Content{Parts: []*genai.Part{{Text: fullSystemPrompt}}},
		},
	)
	if err != nil {
		return "", fmt.Errorf("chat generation failed: %w", err)
	}

	if len(resp.Candidates) == 0 || len(resp.Candidates[0].Content.Parts) == 0 {
		return "", fmt.Errorf("empty response from Gemini")
	}

	responseText := ""
	for _, part := range resp.Candidates[0].Content.Parts {
		if part.Text != "" {
			responseText += part.Text
		}
	}

	return responseText, nil
}

// Helper function to convert to JSON
func (r *TEACHAnalysisResult) ToJSON() (string, error) {
	bytes, err := json.MarshalIndent(r, "", "  ")
	if err != nil {
		return "", err
	}
	return string(bytes), nil
}

func extractJSON(input string) string {
	start := strings.Index(input, "{")
	end := strings.LastIndex(input, "}")
	if start != -1 && end != -1 && end > start {
		return input[start : end+1]
	}
	return input
}
