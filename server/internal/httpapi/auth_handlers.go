package httpapi

import (
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/MultiX0/LocalDrive/server/internal/auth"
	mw "github.com/MultiX0/LocalDrive/server/internal/middleware"
	"github.com/MultiX0/LocalDrive/server/internal/models"
)

type statusResponse struct {
	Name                  string `json:"name"`
	ServerID              string `json:"server_id"`
	Version               string `json:"version"`
	SetupRequired         bool   `json:"setup_required"`
	RequireDeviceApproval bool   `json:"require_device_approval"`
	AllowSelfRegistration bool   `json:"allow_self_registration"`
	Ready                 bool   `json:"ready"`
}

// handleStatus is unauthenticated and deliberately says nothing about users,
// files, or contents. It is what LAN discovery and onboarding read.
func (a *API) handleStatus(w http.ResponseWriter, r *http.Request) {
	cfg := a.settings.Get()
	setupRequired, err := a.auth.SetupRequired(r.Context())
	if err != nil {
		a.fail(w, r, err)
		return
	}
	ready := false
	if list, err := a.libs.List(r.Context()); err == nil {
		for _, lib := range list {
			if lib.Online() {
				ready = true
				break
			}
		}
	}
	writeJSON(w, http.StatusOK, statusResponse{
		Name:                  cfg.ServerName,
		ServerID:              cfg.ServerID,
		Version:               Version,
		SetupRequired:         setupRequired,
		RequireDeviceApproval: cfg.RequireDeviceApproval,
		AllowSelfRegistration: cfg.AllowSelfRegistration,
		Ready:                 ready,
	})
}

type tokenResponse struct {
	AccessToken  string  `json:"access_token"`
	RefreshToken string  `json:"refresh_token,omitempty"`
	ExpiresAt    int64   `json:"expires_at"`
	SessionID    string  `json:"session_id"`
	User         *meBody `json:"user,omitempty"`
	Status       string  `json:"status,omitempty"`
}

type meBody struct {
	ID                 string `json:"id"`
	Username           string `json:"username"`
	DisplayName        string `json:"display_name"`
	Email              string `json:"email,omitempty"`
	Role               string `json:"role"`
	AvatarSeed         string `json:"avatar_seed"`
	QuotaBytes         int64  `json:"quota_bytes"`
	QuotaBytesUsed     int64  `json:"quota_bytes_used"`
	MustChangePassword bool   `json:"must_change_password"`
	TOTPEnabled        bool   `json:"totp_enabled"`

	// MustEnableTOTP is set for an admin who has not set up two factor yet.
	//
	// An admin can change quotas, reset passwords and remove accounts, so the
	// account is worth more than any single member's and is not left protected
	// by a password alone. Members choose for themselves.
	MustEnableTOTP bool  `json:"must_enable_totp"`
	CreatedAt      int64 `json:"created_at"`
}

func userBody(u models.User) *meBody {
	return &meBody{
		ID: u.ID, Username: u.Username, DisplayName: u.PublicName(), Email: u.Email,
		Role: string(u.Role), AvatarSeed: u.AvatarSeed, QuotaBytes: u.QuotaBytes,
		QuotaBytesUsed: u.QuotaBytesUsed, MustChangePassword: u.MustChangePassword,
		TOTPEnabled:    u.TOTPEnabled,
		MustEnableTOTP: u.Role == models.RoleAdmin && !u.TOTPEnabled,
		CreatedAt:      u.CreatedAt,
	}
}

func tokenBody(pair auth.TokenPair) tokenResponse {
	return tokenResponse{
		AccessToken:  pair.AccessToken,
		RefreshToken: pair.RefreshToken,
		ExpiresAt:    pair.ExpiresAt.UnixMilli(),
		SessionID:    pair.SessionID,
		User:         userBody(pair.User),
	}
}

func deviceInfo(r *http.Request, name, platform string) auth.DeviceInfo {
	if strings.TrimSpace(name) == "" {
		name = "Unnamed device"
	}
	return auth.DeviceInfo{
		Name:      strings.TrimSpace(name),
		Platform:  strings.TrimSpace(platform),
		IP:        mw.ClientIPFrom(r.Context()),
		UserAgent: r.UserAgent(),
	}
}

type setupRequest struct {
	Username   string `json:"username"`
	Email      string `json:"email"`
	Password   string `json:"password"`
	ServerName string `json:"server_name"`
	DeviceName string `json:"device_name"`
	Platform   string `json:"platform"`
}

func (a *API) handleSetup(w http.ResponseWriter, r *http.Request) {
	var req setupRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	pair, err := a.auth.Setup(r.Context(), auth.SetupParams{
		Username: req.Username, Email: req.Email, Password: req.Password,
		ServerName: req.ServerName, Device: deviceInfo(r, req.DeviceName, req.Platform),
	})
	if err != nil {
		a.fail(w, r, err)
		return
	}
	a.refreshDiscovery(r.Context())
	writeJSON(w, http.StatusCreated, tokenBody(pair))
}

type registerRequest struct {
	Username   string `json:"username"`
	Email      string `json:"email"`
	Password   string `json:"password"`
	InviteCode string `json:"invite_code"`
	DeviceName string `json:"device_name"`
	Platform   string `json:"platform"`
}

func (a *API) handleRegister(w http.ResponseWriter, r *http.Request) {
	var req registerRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	pair, err := a.auth.Register(r.Context(), auth.RegisterParams{
		Username: req.Username, Email: req.Email, Password: req.Password,
		InviteCode: req.InviteCode, Device: deviceInfo(r, req.DeviceName, req.Platform),
	})
	if err != nil {
		a.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, tokenBody(pair))
}

type loginRequest struct {
	Username   string `json:"username"`
	Password   string `json:"password"`
	TOTPCode   string `json:"totp_code"`
	DeviceName string `json:"device_name"`
	Platform   string `json:"platform"`
}

func (a *API) handleLogin(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	result, err := a.auth.Login(r.Context(), auth.LoginParams{
		Username: req.Username, Password: req.Password, TOTPCode: req.TOTPCode,
		Device: deviceInfo(r, req.DeviceName, req.Platform),
	})
	if err != nil {
		a.fail(w, r, err)
		return
	}
	if result.Pending {
		writeJSON(w, http.StatusAccepted, tokenResponse{
			Status:      "pending",
			SessionID:   result.SessionID,
			AccessToken: result.PendingToken,
		})
		return
	}
	writeJSON(w, http.StatusOK, tokenBody(result.Tokens))
}

type refreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}

func (a *API) handleRefresh(w http.ResponseWriter, r *http.Request) {
	var req refreshRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	pair, err := a.auth.Refresh(r.Context(), req.RefreshToken, mw.ClientIPFrom(r.Context()))
	if err != nil {
		a.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, tokenBody(pair))
}

func (a *API) handleSessionStatus(w http.ResponseWriter, r *http.Request) {
	userID, _ := caller(r)
	status, pair, err := a.auth.SessionStatus(r.Context(), userID, chi.URLParam(r, "id"))
	if err != nil {
		a.fail(w, r, err)
		return
	}
	if pair != nil {
		body := tokenBody(*pair)
		body.Status = string(status)
		writeJSON(w, http.StatusOK, body)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"status": string(status),
		// a client polls this every four to five seconds, no faster
		"poll_after_ms": 4500,
	})
}

func (a *API) handleLogout(w http.ResponseWriter, r *http.Request) {
	userID, ip := caller(r)
	if err := a.auth.Logout(r.Context(), userID, mw.SessionFrom(r.Context()), ip); err != nil {
		a.fail(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *API) handleMe(w http.ResponseWriter, r *http.Request) {
	user, _ := mw.UserFrom(r.Context())
	fresh, err := a.auth.UserByID(r.Context(), user.ID)
	if err != nil {
		a.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, userBody(fresh))
}

type changePasswordRequest struct {
	CurrentPassword string `json:"current_password"`
	NewPassword     string `json:"new_password"`
}

func (a *API) handleChangePassword(w http.ResponseWriter, r *http.Request) {
	var req changePasswordRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	userID, ip := caller(r)
	if err := a.auth.ChangePassword(r.Context(), userID, req.CurrentPassword, req.NewPassword, ip); err != nil {
		a.fail(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type profileRequest struct {
	DisplayName string `json:"display_name"`
}

func (a *API) handleUpdateProfile(w http.ResponseWriter, r *http.Request) {
	var req profileRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	userID, _ := caller(r)
	if err := a.auth.UpdateProfile(r.Context(), userID, req.DisplayName); err != nil {
		a.fail(w, r, err)
		return
	}
	fresh, err := a.auth.UserByID(r.Context(), userID)
	if err != nil {
		a.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, userBody(fresh))
}

func (a *API) handleBeginTOTP(w http.ResponseWriter, r *http.Request) {
	userID, _ := caller(r)
	enrollment, err := a.auth.BeginTOTP(r.Context(), userID)
	if err != nil {
		a.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"secret":         enrollment.Secret,
		"otpauth_url":    enrollment.OTPAuthURL,
		"recovery_codes": enrollment.RecoveryCodes,
	})
}

type totpRequest struct {
	Code     string `json:"code"`
	Password string `json:"password"`
}

func (a *API) handleConfirmTOTP(w http.ResponseWriter, r *http.Request) {
	var req totpRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	userID, ip := caller(r)
	if err := a.auth.ConfirmTOTP(r.Context(), userID, req.Code, ip); err != nil {
		a.fail(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *API) handleDisableTOTP(w http.ResponseWriter, r *http.Request) {
	var req totpRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	userID, ip := caller(r)
	if err := a.auth.DisableTOTP(r.Context(), userID, req.Password, ip); err != nil {
		a.fail(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *API) handleCheckInvite(w http.ResponseWriter, r *http.Request) {
	invite, err := a.auth.CheckInvite(r.Context(), chi.URLParam(r, "code"))
	if err != nil {
		a.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"valid":      true,
		"label":      invite.Label,
		"expires_at": invite.ExpiresAt,
	})
}

// handleListUsers powers the People picker: name and avatar seed only, never
// an email or a role.
func (a *API) handleListUsers(w http.ResponseWriter, r *http.Request) {
	list, err := a.auth.ListPublicUsers(r.Context(), r.URL.Query().Get("q"))
	if err != nil {
		a.fail(w, r, err)
		return
	}
	out := make([]ownerDTO, 0, len(list))
	for _, u := range list {
		out = append(out, ownerDTO{ID: u.ID, Name: u.Name, AvatarSeed: u.AvatarSeed})
	}
	writeJSON(w, http.StatusOK, map[string]any{"users": out})
}

func (a *API) handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"status":     "ok",
		"version":    Version,
		"uptime_sec": int64(time.Since(a.startedAt).Seconds()),
	})
}
