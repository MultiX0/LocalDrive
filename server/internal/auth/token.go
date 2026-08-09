package auth

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Scope narrows what an access token may reach. A device waiting on approval
// gets a pending-scope token that can poll its own status and nothing else.
type Scope string

// Token scopes.
const (
	ScopeFull    Scope = "full"
	ScopePending Scope = "pending"
)

// ErrInvalidToken covers every reason a token was not accepted.
var ErrInvalidToken = errors.New("auth: invalid or expired token")

// Claims is the access token payload.
type Claims struct {
	Scope     Scope  `json:"scope"`
	SessionID string `json:"sid"`
	Role      string `json:"role"`
	jwt.RegisteredClaims
}

// TokenIssuer signs and verifies access tokens.
type TokenIssuer struct {
	secret []byte
	ttl    time.Duration
	issuer string
}

// NewTokenIssuer returns a TokenIssuer over the configured secret.
func NewTokenIssuer(secret []byte, ttl time.Duration, issuer string) *TokenIssuer {
	return &TokenIssuer{secret: secret, ttl: ttl, issuer: issuer}
}

// Issue signs an access token for one session.
func (t *TokenIssuer) Issue(userID, sessionID, role string, scope Scope) (string, time.Time, error) {
	now := time.Now()
	exp := now.Add(t.ttl)
	claims := Claims{
		Scope:     scope,
		SessionID: sessionID,
		Role:      role,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID,
			Issuer:    t.issuer,
			IssuedAt:  jwt.NewNumericDate(now),
			NotBefore: jwt.NewNumericDate(now.Add(-30 * time.Second)),
			ExpiresAt: jwt.NewNumericDate(exp),
			ID:        sessionID,
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := token.SignedString(t.secret)
	if err != nil {
		return "", time.Time{}, err
	}
	return signed, exp, nil
}

// Parse verifies a token's signature and expiry and returns its claims.
func (t *TokenIssuer) Parse(raw string) (*Claims, error) {
	claims := &Claims{}
	parsed, err := jwt.ParseWithClaims(raw, claims, func(token *jwt.Token) (any, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, ErrInvalidToken
		}
		return t.secret, nil
	}, jwt.WithIssuer(t.issuer), jwt.WithValidMethods([]string{"HS256"}))
	if err != nil || !parsed.Valid {
		return nil, ErrInvalidToken
	}
	if claims.Subject == "" || claims.SessionID == "" {
		return nil, ErrInvalidToken
	}
	if claims.Scope != ScopeFull && claims.Scope != ScopePending {
		return nil, ErrInvalidToken
	}
	return claims, nil
}
