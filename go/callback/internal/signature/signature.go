package signature

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"strings"
)

// Verifier 结构体用于验证请求签名
type Verifier struct {
	secret string
}

// NewVerifier 创建一个新的签名验证器
func NewVerifier(secret string) *Verifier {
	return &Verifier{
		secret: secret,
	}
}

// Verify 验证请求的 HMAC-SHA256 签名
func (v *Verifier) Verify(body []byte, signature string) bool {
	// Create a new HMAC hasher
	h := hmac.New(sha256.New, []byte(v.secret))
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
