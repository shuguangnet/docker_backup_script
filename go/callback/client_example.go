//go:build ignore

package main

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
)

const (
	callbackURL     = "http://localhost:47731/backup"
	signatureHeader = "X-Signature"
)

var configFilePath = "../../backup.conf"

// RequestBody represents the JSON structure for the request
type RequestBody struct {
	Args []string `json:"args"`
}

// readConfig reads the configuration file and extracts the callback secret.
func readConfig() (string, error) {
	content, err := os.ReadFile(configFilePath)
	if err != nil {
		return "", fmt.Errorf("failed to read config file: %w", err)
	}

	lines := strings.Split(string(content), "\n")
	for _, line := range lines {
		// Skip comments and empty lines
		trimmedLine := strings.TrimSpace(line)
		if trimmedLine == "" || strings.HasPrefix(trimmedLine, "#") {
			continue
		}

		// Check if the line contains the callback_secret
		if strings.HasPrefix(trimmedLine, "callback_secret") {
			parts := strings.SplitN(trimmedLine, "=", 2)
			if len(parts) == 2 {
				// Remove quotes if present
				secret := strings.TrimSpace(parts[1])
				secret = strings.Trim(secret, "\"'")
				return secret, nil
			}
		}
	}
	return "", fmt.Errorf("callback_secret not found in config file")
}

// generateSignature generates an HMAC-SHA256 signature for the given body using the provided secret.
func generateSignature(body []byte, secret string) string {
	h := hmac.New(sha256.New, []byte(secret))
	h.Write(body)
	signature := h.Sum(nil)
	return "sha256=" + hex.EncodeToString(signature)
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: client_example.go <arg1> [arg2] ...")
		os.Exit(1)
	}

	// Read the callback secret from the config file
	secret, err := readConfig()
	if err != nil {
		fmt.Printf("Error reading config: %v\n", err)
		os.Exit(1)
	}

	// Get command line arguments (excluding program name)
	args := os.Args[1:]

	// Create the request body
	requestBody := RequestBody{
		Args: args,
	}

	// Marshal the request body to JSON
	jsonBody, err := json.Marshal(requestBody)
	if err != nil {
		fmt.Printf("Error marshaling JSON: %v\n", err)
		os.Exit(1)
	}

	// Generate the signature
	signature := generateSignature(jsonBody, secret)

	// Create the HTTP request
	req, err := http.NewRequest("POST", callbackURL, bytes.NewBuffer(jsonBody))
	if err != nil {
		fmt.Printf("Error creating request: %v\n", err)
		os.Exit(1)
	}

	// Set headers
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set(signatureHeader, signature)

	// Send the request
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		fmt.Printf("Error sending request: %v\n", err)
		os.Exit(1)
	}
	defer resp.Body.Close()

	// Read and print the response
	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		fmt.Printf("Error reading response: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Response Status: %s\n", resp.Status)
	fmt.Printf("Response Body: %s\n", string(respBody))
}
