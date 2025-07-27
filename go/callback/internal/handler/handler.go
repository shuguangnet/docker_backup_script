package handler

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"

	"dcoker_backup_script/go/callback/internal/config"
	"dcoker_backup_script/go/callback/internal/response"
	"dcoker_backup_script/go/callback/internal/runner"
	"dcoker_backup_script/go/callback/internal/signature"
)

const (
	signatureHeader = "X-Signature"
)

// RequestBody represents the expected JSON structure for the /backup endpoint
type RequestBody struct {
	Args []string `json:"args"`
}

// BackupHandler 结构体用于处理备份请求
type BackupHandler struct {
	config       *config.Config
	verifier     *signature.Verifier
	scriptRunner func(scriptPath string, args []string) ([]byte, error)
	logger       *slog.Logger
}

// NewBackupHandler 创建一个新的备份处理器
func NewBackupHandler(cfg *config.Config, verifier *signature.Verifier, logger *slog.Logger) *BackupHandler {
	return &BackupHandler{
		config:       cfg,
		verifier:     verifier,
		scriptRunner: runner.Run, // 使用 runner 包中的 Run 函数
		logger:       logger,
	}
}

// ServeHTTP 实现 http.HandlerFunc 接口
func (h *BackupHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		response.Error(w, r, http.StatusMethodNotAllowed, nil, "Method not allowed")
		return
	}

	// Read the request body
	body, err := io.ReadAll(r.Body)
	if err != nil {
		response.Error(w, r, http.StatusInternalServerError, err, "Failed to read request body")
		return
	}
	defer r.Body.Close()

	// Get the signature from the header
	signature := r.Header.Get(signatureHeader)
	if signature == "" {
		response.Error(w, r, http.StatusUnauthorized, nil, "Missing signature")
		return
	}

	// Verify the signature using the raw body
	if !h.verifier.Verify(body, signature) {
		response.Error(w, r, http.StatusUnauthorized, nil, "Invalid signature")
		return
	}

	// Parse the JSON body to extract args
	var args []string
	if len(body) > 0 {
		var requestBody RequestBody
		if err := json.Unmarshal(body, &requestBody); err != nil {
			response.Error(w, r, http.StatusBadRequest, err, "Invalid JSON in request body")
			return
		}
		args = requestBody.Args
	}

	// Execute the backup script with args using the script runner
	output, err := h.scriptRunner(h.config.ScriptPath, args)
	if err != nil {
		h.logger.Error("Failed to execute backup script", "error", err)
		response.Error(w, r, http.StatusInternalServerError, err, "Backup script failed")
		return
	}

	h.logger.Info("Backup script executed successfully", "output", string(output))

	response.JSON(w, r, http.StatusOK, map[string]string{"message": "Backup initiated successfully", "output": string(output)})
}
