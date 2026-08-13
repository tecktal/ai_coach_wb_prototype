package gemini

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
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

// intPtr returns a pointer to an int32
func intPtr(i int32) *int32 {
	return &i
}

// AnalyzeRecording performs combined transcription + TEACH analysis
func (s *GeminiService) AnalyzeRecording(ctx context.Context, audioPath string, language string, audience string, country string) (*TEACHAnalysisResult, error) {
	// 0. Validate audio file exists and is readable
	fileInfo, err := os.Stat(audioPath)
	if err != nil {
		return nil, fmt.Errorf("audio file not accessible: %w", err)
	}

	// Hard reject only truly empty/corrupted files (< 1KB)
	const minSize = 1024 // 1KB
	if fileInfo.Size() < minSize {
		return nil, fmt.Errorf("file_too_small: Audio file is empty or corrupted (%d bytes). Please try recording again.", fileInfo.Size())
	}

	// Hard reject absurdly large files that no API can process (> 500MB)
	const maxSize = 500 * 1024 * 1024 // 500MB
	if fileInfo.Size() > maxSize {
		sizeMB := float64(fileInfo.Size()) / (1024 * 1024)
		return nil, fmt.Errorf("file_too_large: Recording is %.0fMB, which exceeds the 500MB limit. Please use a compressed audio format (M4A or MP3) and try again.", sizeMB)
	}

	// Detect MIME type (simple extension check)
	mimeType := "audio/m4a" // Default for our app
	ext := strings.ToLower(filepath.Ext(audioPath))
	if ext == ".mp3" {
		mimeType = "audio/mp3"
	} else if ext == ".wav" {
		mimeType = "audio/wav"
	}

	// 2. Prepare the prompt
	// The task prompt already contains full TEACH framework guidance.
	fullPrompt := s.GetTEACHAnalysisPrompt(language, audience, country)

	// 3. Build content parts — inline data for small files, File API for large ones
	// Gemini inline data limit is ~20MB (base64 encoded); use File API above 15MB to be safe.
	const inlineLimit = 15 * 1024 * 1024 // 15MB
	var parts []*genai.Part

	if fileInfo.Size() > inlineLimit {
		// Large file: upload via Gemini File API REST endpoint, then reference by URI.
		// (genai SDK v0.5.0 has no Files service; we call the REST API directly.)
		fmt.Printf("[Gemini] File %.1fMB > 15MB, using File API upload\n",
			float64(fileInfo.Size())/(1024*1024))

		fileURI, fileName, err := s.uploadLargeFile(ctx, audioPath, mimeType)
		if err != nil {
			return nil, fmt.Errorf("failed to upload large audio file: %w", err)
		}
		// Best-effort delete after analysis completes
		defer s.deleteLargeFile(ctx, fileName)

		parts = []*genai.Part{
			{FileData: &genai.FileData{FileURI: fileURI, MIMEType: mimeType}},
			{Text: fullPrompt},
		}
	} else {
		// Small file: embed inline as base64
		audioData, err := os.ReadFile(audioPath)
		if err != nil {
			return nil, fmt.Errorf("failed to read audio file: %w", err)
		}
		parts = []*genai.Part{
			{InlineData: &genai.Blob{MIMEType: mimeType, Data: audioData}},
			{Text: fullPrompt},
		}
	}

	temperature := float32(0) // Zero temperature for fully deterministic, consistent analysis

	// Retry logic for 503 Overloaded errors
	var resp *genai.GenerateContentResponse

	maxRetries := 6
	for i := 0; i < maxRetries; i++ {
		resp, err = s.client.Models.GenerateContent(
			ctx,
			"gemini-2.5-flash",
			[]*genai.Content{{Parts: parts, Role: "user"}},
			&genai.GenerateContentConfig{
				Temperature:     &temperature,
				MaxOutputTokens: intPtr(65536), // Flash maximum — full budget for JSON
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
				// Exponential backoff: 5s, 10s, 20s, 40s, 80s, 160s
				// This handles the "Please retry in 31s" guidance from the API
				backoff := time.Duration(5*(1<<i)) * time.Second
				fmt.Printf("Gemini Busy/Rate Limit (%s). Retrying in %v...\n", err, backoff)
				time.Sleep(backoff)
				continue
			}
		}

		// If other error or max retries reached
		return nil, fmt.Errorf("gemini generation failed: %w", err)
	}

	if len(resp.Candidates) == 0 {
		return nil, fmt.Errorf("empty response from Gemini (no candidates)")
	}

	// Log finish reason for debugging
	finishReason := resp.Candidates[0].FinishReason
	if finishReason != genai.FinishReasonStop {
		fmt.Printf("WARNING: Gemini finished with reason: %v\n", finishReason)
		if fmt.Sprintf("%v", finishReason) == "MAX_TOKENS" {
			return nil, fmt.Errorf("gemini_token_limit: Maximum token limit exceeded (output too long)")
		}
	}

	if len(resp.Candidates[0].Content.Parts) == 0 {
		return nil, fmt.Errorf("empty response from Gemini (no content parts)")
	}

	// 4. Parse the response
	jsonText := ""
	for _, part := range resp.Candidates[0].Content.Parts {
		if part.Text != "" {
			jsonText += part.Text
		}
	}

	extractedJSON := extractJSON(jsonText)
	cleanedJSON := cleanGeminiJSON(extractedJSON)
	var result TEACHAnalysisResult
	if err := json.Unmarshal([]byte(cleanedJSON), &result); err != nil {
		// Regex cleanup wasn't sufficient — ask Gemini to correct its own formatting.
		// This handles cases like "text" (1:02) that the regex didn't catch.
		fmt.Printf("INFO: JSON parse failed (%v), attempting AI self-correction...\n", err)
		fixedJSON, fixErr := s.fixMalformedJSON(ctx, cleanedJSON)
		if fixErr == nil {
			if err2 := json.Unmarshal([]byte(fixedJSON), &result); err2 != nil {
				fmt.Printf("DEBUG: Failed JSON Trace (after AI fix): %s\n", fixedJSON)
				return nil, fmt.Errorf("failed to parse JSON response after AI correction: %w - Length: %d", err2, len(jsonText))
			}
			fmt.Println("INFO: AI self-correction succeeded.")
		} else {
			fmt.Printf("DEBUG: Failed JSON Trace: %s\n", jsonText)
			return nil, fmt.Errorf("failed to parse JSON response: %w - Length: %d", err, len(jsonText))
		}
	}

	// Check if Gemini returned an insufficient_audio hard-failure
	// This should now be rare — only for completely silent/corrupted audio
	if result.Error == "insufficient_audio" {
		return nil, fmt.Errorf("insufficient_audio: %s (detected duration: %d seconds)",
			result.Message, result.DetectedDuration)
	}

	// A content_warning is allowed — it is propagated alongside the analysis result.
	if result.ContentWarning != nil {
		fmt.Printf("[Gemini] Content warning (%s): %s (detected %ds)\n",
			result.ContentWarning.Type, result.ContentWarning.Message, result.ContentWarning.DetectedSeconds)
	}

	// Validate analysis result to detect hallucination or empty responses
	// Check if analysis seems valid (has a score and at least one element)
	if result.OverallScore == 0 {
		return nil, fmt.Errorf("parsed result has no overall score, analysis likely failed or audio was empty")
	}

	// Check if at least one element has a valid score (> 0)
	hasValidElement := false
	for _, element := range result.Elements {
		if element.Score > 0 {
			hasValidElement = true
			break
		}
	}
	if !hasValidElement {
		return nil, fmt.Errorf("no valid element scores found, analysis likely failed or audio was empty")
	}

	return &result, nil
}

// GetCoachingResponseStream generates a coaching chat response using streaming
// GenerateCoachScript builds the seven-block coaching conversation for one TEACH
// element, from the stored analysis rather than the audio.
//
// [elementAnalysisJSON] is that element's persisted `*_behaviors` object, which
// already holds the evidence quotes and rationale extracted during the TEACH
// analysis — so this is a cheap, text-only second call with no re-upload.
func (s *GeminiService) GenerateCoachScript(
	ctx context.Context,
	elementLabel, subject, gradeLevel, elementAnalysisJSON, language string,
) (*CoachScriptResult, error) {
	prompt := GetCoachScriptPrompt(elementLabel, subject, gradeLevel, elementAnalysisJSON, language)

	// Slightly above zero: these are coaching questions, and identical phrasing
	// across every lesson would make the tool feel canned. Still low enough to
	// stay grounded in the supplied evidence.
	temperature := float32(0.3)

	var resp *genai.GenerateContentResponse
	var err error

	const maxRetries = 4
	for i := 0; i < maxRetries; i++ {
		resp, err = s.client.Models.GenerateContent(
			ctx,
			"gemini-2.5-flash",
			[]*genai.Content{{Parts: []*genai.Part{{Text: prompt}}, Role: "user"}},
			&genai.GenerateContentConfig{
				Temperature:     &temperature,
				MaxOutputTokens: intPtr(4096),
			},
		)
		if err == nil {
			break
		}

		errStr := strings.ToLower(err.Error())
		retryable := strings.Contains(errStr, "503") || strings.Contains(errStr, "overloaded") ||
			strings.Contains(errStr, "429") || strings.Contains(errStr, "resource exhausted") ||
			strings.Contains(errStr, "quota")
		if retryable && i < maxRetries-1 {
			backoff := time.Duration(3*(1<<i)) * time.Second
			fmt.Printf("Gemini busy generating coach script (%s). Retrying in %v...\n", err, backoff)
			time.Sleep(backoff)
			continue
		}
		return nil, fmt.Errorf("coach script generation failed: %w", err)
	}

	if len(resp.Candidates) == 0 || len(resp.Candidates[0].Content.Parts) == 0 {
		return nil, fmt.Errorf("empty response from Gemini")
	}

	jsonText := ""
	for _, part := range resp.Candidates[0].Content.Parts {
		jsonText += part.Text
	}

	// Same recovery ladder as the TEACH analysis: extract, clean, then ask the
	// model to repair its own output before giving up.
	cleaned := cleanGeminiJSON(extractJSON(jsonText))

	var result CoachScriptResult
	if err := json.Unmarshal([]byte(cleaned), &result); err != nil {
		fmt.Printf("INFO: coach script JSON parse failed (%v), attempting AI self-correction...\n", err)
		fixed, fixErr := s.fixMalformedJSON(ctx, cleaned)
		if fixErr != nil {
			return nil, fmt.Errorf("failed to parse coach script JSON: %w", err)
		}
		if err2 := json.Unmarshal([]byte(fixed), &result); err2 != nil {
			return nil, fmt.Errorf("failed to parse coach script JSON after correction: %w", err2)
		}
	}

	if result.CoachQuestion == "" {
		return nil, fmt.Errorf("coach script missing its opening question")
	}

	return &result, nil
}

// languageName maps a BCP-47 code onto the English name used in prompts.
func languageName(code string) string {
	switch code {
	case "pt":
		return "Portuguese"
	case "fr":
		return "French"
	case "am":
		return "Amharic"
	case "sw":
		return "Swahili"
	default:
		return "English"
	}
}

// buildCoachingSystemPrompt returns the chat system prompt for the given
// language and audience.
//
// Shared by the streaming and blocking coaching calls, which previously held
// byte-identical copies of this text.
func buildCoachingSystemPrompt(language, audience string) string {
	var systemPrompt string

	if NormalizeAudience(audience) == AudienceCoordinator {
		// The reader is a pedagogy coach preparing to discuss the lesson with
		// the teacher who taught it. They are not the subject of the feedback.
		systemPrompt = `You are supporting a pedagogy coordinator who observed a lesson and is preparing to discuss it with the teacher who taught it.

CRITICAL — WHO YOU ARE TALKING TO:
- You are talking to the COORDINATOR, not the teacher.
- Refer to the teacher in the THIRD PERSON ("the teacher", "she", "he"). NEVER address the teacher as "you".
- "You" refers to the coordinator only.

Your role:
- Answer the coordinator's questions about the lesson analysis
- Offer questions the coordinator could ask the teacher, and things worth exploring together
- Ground every suggestion in specific evidence from the lesson
- Suggest concrete strategies the coordinator could offer the teacher
- Answer general educational and subject-matter questions (e.g., math formulas, science facts, grammar) to support the conversation
- Keep responses under 300 words

HOW TO PHRASE THINGS:
- Give the coordinator material for a conversation, not a script to read aloud.
- Prefer "a way in could be..." or "worth exploring together..." over "tell her to...".
- Describe what was observed. Do not pass judgement on the teacher.
- Never use deficit language ("failed to", "should have", "didn't"). State what was and was not audible.`
	} else {
		// Unchanged from the original single-audience prompt.
		systemPrompt = `You are an AI teaching coach helping a teacher improve based on their TEACH analysis.
Your role:
- Answer questions about their lesson analysis
- Provide specific, actionable teaching strategies
- Give concrete examples they can use tomorrow
- Be supportive and encouraging while being honest
- Answer general educational and subject-matter questions (e.g., math formulas, science facts, grammar) to assist with lesson planning and testing
- Keep responses under 300 words
Reference specific evidence from their lesson when giving advice.`
	}

	systemPrompt += `
FORMATTING RULES (mandatory):
- You MUST format all numbers, equations, and math symbols using LaTeX.
- You MUST wrap inline math exclusively in \( and \) (Example: "We see that \( 2 \times 3 = 6 \)").
- You MUST wrap block equations exclusively in \[ and \] on their own line.
- Under no circumstances should you use any other delimiters for math. NEVER use Unicode superscripts (e.g. x²) or plain-text math.`

	systemPrompt += fmt.Sprintf(
		"\n\nCRITICAL INSTRUCTION: You MUST reply in the **%s** language.",
		languageName(language),
	)

	return systemPrompt
}

func (s *GeminiService) GetCoachingResponseStream(ctx context.Context, conversationHistory []map[string]string, analysisContext string, language string, audience string, onChunk func(string) error) error {
	// Build parts from history
	var contents []*genai.Content

	fullSystemPrompt := buildCoachingSystemPrompt(language, audience) +
		"\n\nContext from their recent lesson:\n" + analysisContext

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

	// Use GenerateContentStream
	iter := s.client.Models.GenerateContentStream(
		ctx,
		"gemini-2.5-flash",
		contents,
		&genai.GenerateContentConfig{
			Temperature:       &temperature,
			SystemInstruction: &genai.Content{Parts: []*genai.Part{{Text: fullSystemPrompt}}},
		},
	)

	// Iterate through the stream - using Go 1.23+ iterators
	for resp, err := range iter {
		if err != nil {
			return err
		}

		if len(resp.Candidates) > 0 {
			for _, part := range resp.Candidates[0].Content.Parts {
				text := part.Text
				if text != "" {
					if err := onChunk(text); err != nil {
						return err
					}
				}
			}
		}
	}

	return nil
}

// GetCoachingResponse generates a coaching chat response (Blocking version - Legacy)
func (s *GeminiService) GetCoachingResponse(ctx context.Context, conversationHistory []map[string]string, analysisContext string, language string, audience string) (string, error) {
	// Build parts from history
	var contents []*genai.Content

	fullSystemPrompt := buildCoachingSystemPrompt(language, audience) +
		"\n\nContext from their recent lesson:\n" + analysisContext

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
		"gemini-2.5-flash", // Using same model as lesson analysis
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

// fixMalformedJSON asks Gemini to correct only JSON formatting errors in the
// given text, without changing any analysis content or scores.
// Used as a fallback when regex cleanup is insufficient.
func (s *GeminiService) fixMalformedJSON(ctx context.Context, malformedJSON string) (string, error) {
	prompt := `You are a JSON repair tool. The following JSON has formatting errors.

The ONLY type of error to fix is timestamps placed outside string quotes in arrays, for example:
  BROKEN:  "instances_found": ["Mary" (1:02), "Joshua" (4:00)]
  FIXED:   "instances_found": ["Mary (1:02)", "Joshua (4:00)"]

Rules:
- Fix ONLY JSON formatting errors. Do NOT change any content, scores, ratings, or analysis values.
- Return ONLY the corrected JSON. No explanation, no markdown, no surrounding text.
- If the JSON is already valid, return it unchanged.

JSON to fix:
` + malformedJSON

	temperature := float32(0)
	resp, err := s.client.Models.GenerateContent(
		ctx,
		"gemini-2.5-flash",
		[]*genai.Content{{Parts: []*genai.Part{{Text: prompt}}, Role: "user"}},
		&genai.GenerateContentConfig{
			Temperature:     &temperature,
			MaxOutputTokens: intPtr(32768),
		},
	)
	if err != nil {
		return "", fmt.Errorf("AI JSON correction call failed: %w", err)
	}

	if len(resp.Candidates) == 0 || len(resp.Candidates[0].Content.Parts) == 0 {
		return "", fmt.Errorf("empty response from AI JSON correction")
	}

	text := ""
	for _, part := range resp.Candidates[0].Content.Parts {
		if part.Text != "" {
			text += part.Text
		}
	}
	return extractJSON(text), nil
}

// cleanGeminiJSON fixes a recurring Gemini output bug where timestamps are
// placed outside string quotes in instances_found arrays:
//
//	["Mary" (1:02), "Joshua" (4:00)]  →  ["Mary (1:02)", "Joshua (4:00)"]
//
// This makes the JSON valid before unmarshalling.
func cleanGeminiJSON(input string) string {
	// Pattern: a closing quote followed by optional whitespace then (mm:ss)
	// e.g.  "Some text" (1:02)  →  "Some text (1:02)"
	re := regexp.MustCompile(`"([^"\n]*)"\s*(\(\d+:\d+\))`)
	return re.ReplaceAllString(input, `"$1 $2"`)
}

// uploadLargeFile uploads an audio file > 15MB to the Gemini File API using
// the REST multipart upload protocol, which is not available in genai SDK v0.5.0.
// Returns the file URI (for content parts) and the file name (for deletion).
func (s *GeminiService) uploadLargeFile(ctx context.Context, audioPath string, mimeType string) (string, string, error) {
	audioData, err := os.ReadFile(audioPath)
	if err != nil {
		return "", "", fmt.Errorf("failed to read audio file: %w", err)
	}

	const boundary = "gemini_upload_boundary"

	var body bytes.Buffer
	// Metadata part
	body.WriteString("--" + boundary + "\r\n")
	body.WriteString("Content-Type: application/json; charset=UTF-8\r\n\r\n")
	metaJSON := `{"file":{"display_name":"` + filepath.Base(audioPath) + `"}}`
	body.WriteString(metaJSON + "\r\n")
	// Audio data part
	body.WriteString("--" + boundary + "\r\n")
	body.WriteString("Content-Type: " + mimeType + "\r\n\r\n")
	body.Write(audioData)
	body.WriteString("\r\n--" + boundary + "--")

	uploadURL := fmt.Sprintf(
		"https://generativelanguage.googleapis.com/upload/v1beta/files?key=%s", s.apiKey)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, uploadURL, &body)
	if err != nil {
		return "", "", fmt.Errorf("failed to build upload request: %w", err)
	}
	req.Header.Set("Content-Type", "multipart/related; boundary="+boundary)
	req.Header.Set("X-Goog-Upload-Protocol", "multipart")

	httpClient := &http.Client{Timeout: 5 * time.Minute}
	resp, err := httpClient.Do(req)
	if err != nil {
		return "", "", fmt.Errorf("file upload request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return "", "", fmt.Errorf("file upload failed (HTTP %d): %s", resp.StatusCode, string(respBody))
	}

	var result struct {
		File struct {
			Name string `json:"name"`
			URI  string `json:"uri"`
		} `json:"file"`
	}
	if err := json.Unmarshal(respBody, &result); err != nil {
		return "", "", fmt.Errorf("failed to parse upload response: %w", err)
	}

	return result.File.URI, result.File.Name, nil
}

// deleteLargeFile removes a previously uploaded file from the Gemini File API.
// Runs best-effort — failures are logged but never returned as errors.
func (s *GeminiService) deleteLargeFile(ctx context.Context, fileName string) {
	if fileName == "" {
		return
	}
	deleteURL := fmt.Sprintf(
		"https://generativelanguage.googleapis.com/v1beta/%s?key=%s", fileName, s.apiKey)
	req, err := http.NewRequestWithContext(ctx, http.MethodDelete, deleteURL, nil)
	if err != nil {
		fmt.Printf("[Gemini] Warning: failed to build delete request for %s: %v\n", fileName, err)
		return
	}
	httpClient := &http.Client{Timeout: 30 * time.Second}
	resp, err := httpClient.Do(req)
	if err != nil {
		fmt.Printf("[Gemini] Warning: failed to delete file %s: %v\n", fileName, err)
		return
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		fmt.Printf("[Gemini] Warning: delete file %s returned HTTP %d\n", fileName, resp.StatusCode)
	}
}
