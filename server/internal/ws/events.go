// Package ws is the live-change hub: one connection per active client, events
// scoped to the users who may see them, and a bounded outbound queue per
// client so one slow reader can never stall the rest.
package ws

import "encoding/json"

// Event type names, matching the client's switch exactly.
const (
	EventNodeCreated     = "node.created"
	EventNodeUpdated     = "node.updated"
	EventNodeMoved       = "node.moved"
	EventNodeDeleted     = "node.deleted"
	EventNodeRestored    = "node.restored"
	EventNodeThumbnail   = "node.thumbnail_ready"
	EventQuotaUpdated    = "quota.updated"
	EventDevicePending   = "device.pending"
	EventDeviceApproved  = "device.approved"
	EventDeviceDenied    = "device.denied"
	EventShareReceived   = "share.received"
	EventLibraryChanged  = "library.changed"
	EventSettingsChanged = "server.settings_changed"
	EventSessionRevoked  = "session.revoked"
)

// Event is one message pushed to a client.
type Event struct {
	Type    string          `json:"type"`
	At      int64           `json:"at"`
	Payload json.RawMessage `json:"payload,omitempty"`
}

// NewEvent marshals payload into an Event, returning an empty payload if the
// value cannot be encoded rather than failing the mutation that emitted it.
func NewEvent(eventType string, at int64, payload any) Event {
	e := Event{Type: eventType, At: at}
	if payload != nil {
		if encoded, err := json.Marshal(payload); err == nil {
			e.Payload = encoded
		}
	}
	return e
}
