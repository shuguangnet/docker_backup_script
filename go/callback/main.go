package main

import (
	"net/http"

	"dcoker_backup_script/go/callback/internal/config"
	"dcoker_backup_script/go/callback/internal/handler"
	"dcoker_backup_script/go/callback/internal/logger"
	"dcoker_backup_script/go/callback/internal/signature"
)

const (
	configFilePath = "backup.conf"
)

func main() {
	// Initialize logger
	logger := logger.New()

	// Load configuration
	cfg, err := config.LoadConfig(configFilePath)
	if err != nil {
		logger.Error("Error loading config", "error", err)
		return
	}

	// Initialize dependencies
	verifier := signature.NewVerifier(cfg.CallbackSecret)
	backupHandler := handler.NewBackupHandler(cfg, verifier, logger)

	// Set up the HTTP handler
	http.Handle("/backup", backupHandler)

	// Start the HTTP server
	logger.Info("Starting server", "port", cfg.Port)
	err = http.ListenAndServe(":"+cfg.Port, nil)
	if err != nil {
		logger.Error("Server failed to start", "error", err)
		return
	}
}
