package middleware

import (
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/http/httptest"
	"testing"
)

// The logging middleware wraps the ResponseWriter. A websocket upgrade needs
// the raw connection, and the library asks for it with a plain
// w.(http.Hijacker) assertion rather than through http.ResponseController.
//
// This shipped broken once: the wrapper had Unwrap but no Hijack, so every
// upgrade was answered 501 and the app never received a single event. Nothing
// caught it, because no test put the middleware and the upgrade together.
func TestLoggerKeepsResponseWriterHijackable(t *testing.T) {
	var (
		sawHijacker bool
		hijackErr   error
	)

	handler := Logger(slog.New(slog.DiscardHandler))(
		http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			hijacker, ok := w.(http.Hijacker)
			sawHijacker = ok
			if !ok {
				return
			}
			conn, _, err := hijacker.Hijack()
			hijackErr = err
			if conn != nil {
				conn.Close()
			}
		}),
	)

	server := httptest.NewServer(handler)
	defer server.Close()

	conn, err := net.Dial("tcp", server.Listener.Addr().String())
	if err != nil {
		t.Fatalf("dial: %v", err)
	}
	defer conn.Close()

	if _, err := io.WriteString(conn, "GET / HTTP/1.1\r\nHost: x\r\n\r\n"); err != nil {
		t.Fatalf("write: %v", err)
	}
	// read so the handler has certainly run before the assertions below
	buf := make([]byte, 64)
	_, _ = conn.Read(buf)

	if !sawHijacker {
		t.Fatal("the wrapped ResponseWriter does not implement http.Hijacker, " +
			"so every websocket upgrade would be answered with 501")
	}
	if hijackErr != nil {
		t.Fatalf("Hijack returned %v", hijackErr)
	}
}

// A writer that cannot hijack has to return the error rather than panic, and
// must not claim an upgrade that never happened.
func TestHijackOnAWriterThatCannotHijack(t *testing.T) {
	recorder := &statusRecorder{
		ResponseWriter: httptest.NewRecorder(),
		status:         http.StatusOK,
	}

	if _, _, err := recorder.Hijack(); err == nil {
		t.Fatal("expected an error from a writer that cannot hijack")
	}
	if recorder.status != http.StatusOK {
		t.Fatalf("status = %d, want it left at %d since no upgrade happened",
			recorder.status, http.StatusOK)
	}
}
