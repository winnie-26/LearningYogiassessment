package crypto

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"io"
)

// WrapKey encrypts a 16-byte group key with a 32-byte master key using AES-256-GCM.
func WrapKey(masterKey []byte, groupKey []byte) (ciphertext, nonce string, err error) {
	if len(masterKey) != 32 { return "", "", errors.New("master key must be 32 bytes") }
	block, err := aes.NewCipher(masterKey)
	if err != nil { return "", "", err }
	gcm, err := cipher.NewGCM(block)
	if err != nil { return "", "", err }
	n := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, n); err != nil { return "", "", err }
	ct := gcm.Seal(nil, n, groupKey, nil)
	return base64.StdEncoding.EncodeToString(ct), base64.StdEncoding.EncodeToString(n), nil
}

// UnwrapKey decrypts the wrapped group key
func UnwrapKey(masterKey []byte, b64ct, b64nonce string) ([]byte, error) {
	if len(masterKey) != 32 { return nil, errors.New("master key must be 32 bytes") }
	ct, err := base64.StdEncoding.DecodeString(b64ct)
	if err != nil { return nil, err }
	n, err := base64.StdEncoding.DecodeString(b64nonce)
	if err != nil { return nil, err }
	block, err := aes.NewCipher(masterKey)
	if err != nil { return nil, err }
	gcm, err := cipher.NewGCM(block)
	if err != nil { return nil, err }
	pt, err := gcm.Open(nil, n, ct, nil)
	if err != nil { return nil, err }
	return pt, nil
}

// EncryptMessage encrypts plaintext with AES-128-GCM using provided 16-byte key
func EncryptMessage(key []byte, plaintext []byte) (ciphertext, nonce string, err error) {
	if len(key) != 16 { return "", "", errors.New("key must be 16 bytes") }
	block, err := aes.NewCipher(key)
	if err != nil { return "", "", err }
	gcm, err := cipher.NewGCM(block)
	if err != nil { return "", "", err }
	n := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, n); err != nil { return "", "", err }
	ct := gcm.Seal(nil, n, plaintext, nil)
	return base64.StdEncoding.EncodeToString(ct), base64.StdEncoding.EncodeToString(n), nil
}

// DecryptMessage decrypts AES-128-GCM ciphertext
func DecryptMessage(key []byte, b64ct, b64nonce string) ([]byte, error) {
	if len(key) != 16 { return nil, errors.New("key must be 16 bytes") }
	ct, err := base64.StdEncoding.DecodeString(b64ct)
	if err != nil { return nil, err }
	n, err := base64.StdEncoding.DecodeString(b64nonce)
	if err != nil { return nil, err }
	block, err := aes.NewCipher(key)
	if err != nil { return nil, err }
	gcm, err := cipher.NewGCM(block)
	if err != nil { return nil, err }
	pt, err := gcm.Open(nil, n, ct, nil)
	if err != nil { return nil, err }
	return pt, nil
}
