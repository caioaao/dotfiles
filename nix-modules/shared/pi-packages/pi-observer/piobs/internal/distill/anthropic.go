package distill

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

// anthropicClient is a minimal Messages API client - one POST with JSON;
// an SDK buys nothing here. Auth is ANTHROPIC_API_KEY only (v1).
type anthropicClient struct {
	apiKey    string
	model     string
	maxTokens int
	http      *http.Client
}

// ErrNoAPIKey lets callers (the TUI banner) distinguish missing auth from
// transient failures.
var ErrNoAPIKey = fmt.Errorf("ANTHROPIC_API_KEY not set")

func newAnthropicClient(cfg Config) (*anthropicClient, error) {
	key := os.Getenv("ANTHROPIC_API_KEY")
	if key == "" {
		return nil, ErrNoAPIKey
	}
	return &anthropicClient{
		apiKey:    key,
		model:     cfg.ModelID,
		maxTokens: cfg.MaxTokens,
		http:      &http.Client{Timeout: 120 * time.Second},
	}, nil
}

func (c *anthropicClient) complete(ctx context.Context, system, prompt string) (string, error) {
	body, err := json.Marshal(map[string]any{
		"model":      c.model,
		"max_tokens": c.maxTokens,
		"system":     system,
		"messages": []map[string]any{
			{"role": "user", "content": prompt},
		},
	})
	if err != nil {
		return "", err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "https://api.anthropic.com/v1/messages", bytes.NewReader(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("content-type", "application/json")
	req.Header.Set("x-api-key", c.apiKey)
	req.Header.Set("anthropic-version", "2023-06-01")

	resp, err := c.http.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return "", err
	}
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("anthropic: %s: %s", resp.Status, truncateErr(raw))
	}
	var parsed struct {
		Content []struct {
			Type string `json:"type"`
			Text string `json:"text"`
		} `json:"content"`
	}
	if err := json.Unmarshal(raw, &parsed); err != nil {
		return "", fmt.Errorf("anthropic: bad response: %w", err)
	}
	var out string
	for _, c := range parsed.Content {
		if c.Type == "text" {
			out += c.Text
		}
	}
	return out, nil
}

func truncateErr(raw []byte) string {
	s := string(raw)
	if len(s) > 300 {
		s = s[:300] + "..."
	}
	return s
}
