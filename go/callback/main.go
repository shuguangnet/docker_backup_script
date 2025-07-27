package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strings"
)

const (
	configFilePath    = "backup.conf"
	scriptPath        = "docker-backup.sh"
	port              = "47731"
	callbackSecretKey = "callback_secret"
	signatureHeader   = "X-Signature"
)

// RequestBody represents the expected JSON structure for the /backup endpoint
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
		if strings.HasPrefix(trimmedLine, callbackSecretKey) {
			parts := strings.SplitN(trimmedLine, "=", 2)
			if len(parts) == 2 {
				return strings.TrimSpace(parts[1]), nil
			}
		}
	}
	return "", fmt.Errorf("callback_secret not found in config file")
}

// verifySignature verifies the HMAC-SHA256 signature of the request.
func verifySignature(body []byte, signature string, secret string) bool {
	// Create a new HMAC hasher
	h := hmac.New(sha256.New, []byte(secret))
	h.Write(body)
	expectedMAC := h.Sum(nil)

	// Decode the received signature (assuming it's hex encoded and prefixed with 'sha256=')
	signature = strings.TrimPrefix(signature, "sha256=")

	// Decode the received signature from hex
	receivedMAC, err := hex.DecodeString(signature)
	if err != nil {
		return false
	}

	// Compare the signatures securely
	return hmac.Equal(expectedMAC, receivedMAC)
}

// handleBackup handles the /backup endpoint.
func handleBackup(secret string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		// Read the request body
		body, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "Failed to read request body", http.StatusInternalServerError)
			return
		}
		defer r.Body.Close()

		// Get the signature from the header
		signature := r.Header.Get(signatureHeader)
		if signature == "" {
			http.Error(w, "Missing signature", http.StatusUnauthorized)
			return
		}

		// Verify the signature using the raw body
		if !verifySignature(body, signature, secret) {
			http.Error(w, "Invalid signature", http.StatusUnauthorized)
			return
		}

		// Parse the JSON body to extract args
		var args []string
		if len(body) > 0 {
			var requestBody RequestBody
			if err := json.Unmarshal(body, &requestBody); err != nil {
				http.Error(w, "Invalid JSON in request body", http.StatusBadRequest)
				return
			}
			args = requestBody.Args
		}

		// Prepare command with script path and args
		cmdArgs := []string{scriptPath}
		cmdArgs = append(cmdArgs, args...)

		// Execute the backup script with args
		cmd := exec.Command("/bin/bash", cmdArgs...)
		cmd.Dir = "../.." // Set working directory to project root
		output, err := cmd.CombinedOutput()
		if err != nil {
			log.Printf("Failed to execute backup script: %v\nOutput: %s", err, string(output))
			http.Error(w, "Backup script failed", http.StatusInternalServerError)
			return
		}

		log.Printf("Backup script executed successfully:\n%s", string(output))
		w.WriteHeader(http.StatusOK)
		fmt.Fprintln(w, "Backup initiated successfully")
	}
}

func main() {
	// Read the callback secret from the config file
	secret, err := readConfig()
	if err != nil {
		log.Fatalf("Error reading config: %v", err)
	}

	// Set up the HTTP handler
	http.HandleFunc("/backup", handleBackup(secret))

	// Start the HTTP server
	log.Printf("Starting server on port %s", port)
	err = http.ListenAndServe(":"+port, nil)
	if err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}
