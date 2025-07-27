package logger

import (
	"log/slog"
	"os"
)

// New 创建并返回一个配置好的 slog.Logger 实例
func New() *slog.Logger {
	// 创建一个 JSON 格式的日志处理器
	handler := slog.NewJSONHandler(os.Stdout, nil)

	// 创建并返回 logger 实例
	return slog.New(handler)
}
