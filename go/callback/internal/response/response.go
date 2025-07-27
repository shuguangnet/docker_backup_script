package response

import (
	"encoding/json"
	"log/slog"
	"net/http"
)

// JSON 发送成功的 JSON 响应
func JSON(w http.ResponseWriter, r *http.Request, statusCode int, data any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)

	if err := json.NewEncoder(w).Encode(data); err != nil {
		slog.Error("Failed to encode JSON response", "error", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
	}
}

// Error 发送标准化的 JSON 错误响应
func Error(w http.ResponseWriter, r *http.Request, statusCode int, err error, message string) {
	// 记录错误日志
	if err != nil {
		slog.Error(message, "error", err)
	} else {
		slog.Error(message)
	}

	// 发送 JSON 错误响应
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)

	errorResponse := map[string]string{"error": message}
	if err := json.NewEncoder(w).Encode(errorResponse); err != nil {
		slog.Error("Failed to encode JSON error response", "error", err)
		// 如果 JSON 编码失败，发送纯文本错误
		http.Error(w, "Internal server error", http.StatusInternalServerError)
	}
}
