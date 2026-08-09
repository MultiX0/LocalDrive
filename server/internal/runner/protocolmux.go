package runner

import (
	"bytes"
	"crypto/tls"
	"io"
	"net"
	"sync"
	"time"
)

// A tls record opens with the handshake content type. A plain http request
// opens with a method, which is a letter. One byte separates them, and that is
// the whole trick that lets a single port answer both.
const tlsRecordHandshake = 0x16

// peekTimeout bounds how long a connection may stay silent before it is
// dropped. Without it a client that connects and then says nothing holds a
// goroutine and a file descriptor for as long as it likes.
const peekTimeout = 20 * time.Second

// bothProtocols is a listener that answers https and plain http on one port.
//
// A server with a domain holds a certificate for that name and no other, so
// https to its ip address cannot work: the handshake is refused before a
// request is ever sent, and no authority will issue a certificate for
// 192.168.x.x to change that. Without this, setting a domain would quietly
// take away every way of reaching the server by address, which is how a phone
// on the same wifi gets to it. Sniffing the first byte lets the name keep its
// certificate while an address on the network keeps a route that works.
type bothProtocols struct {
	inner  net.Listener
	config *tls.Config

	conns chan net.Conn
	fail  chan error
	done  chan struct{}
	once  sync.Once
}

// listenBothProtocols opens a port that accepts either protocol.
func listenBothProtocols(network, addr string, config *tls.Config) (net.Listener, error) {
	inner, err := net.Listen(network, addr)
	if err != nil {
		return nil, err
	}
	return serveBothProtocols(inner, config), nil
}

// serveBothProtocols wraps a listener that is already open, which is what the
// tests use.
func serveBothProtocols(inner net.Listener, config *tls.Config) net.Listener {
	l := &bothProtocols{
		inner:  inner,
		config: config,
		conns:  make(chan net.Conn),
		fail:   make(chan error, 1),
		done:   make(chan struct{}),
	}
	go l.accept()
	return l
}

func (l *bothProtocols) accept() {
	for {
		conn, err := l.inner.Accept()
		if err != nil {
			select {
			case l.fail <- err:
			case <-l.done:
			}
			return
		}
		// deciding which protocol this is means reading from the connection, so
		// it cannot happen here: one silent client would stop the server
		// accepting anything else at all
		go l.classify(conn)
	}
}

func (l *bothProtocols) classify(conn net.Conn) {
	if err := conn.SetReadDeadline(time.Now().Add(peekTimeout)); err != nil {
		conn.Close()
		return
	}

	first := make([]byte, 1)
	if _, err := io.ReadFull(conn, first); err != nil {
		conn.Close()
		return
	}

	if err := conn.SetReadDeadline(time.Time{}); err != nil {
		conn.Close()
		return
	}

	// hand the byte back, so whatever reads next sees an untouched stream
	var out net.Conn = &replayConn{
		Conn:   conn,
		reader: io.MultiReader(bytes.NewReader(first), conn),
	}
	if first[0] == tlsRecordHandshake {
		// net/http recognises a *tls.Conn and runs the handshake itself, which
		// is also what sets r.TLS and negotiates http/2
		out = tls.Server(out, l.config)
	}

	select {
	case l.conns <- out:
	case <-l.done:
		out.Close()
	}
}

func (l *bothProtocols) Accept() (net.Conn, error) {
	select {
	case conn := <-l.conns:
		return conn, nil
	case err := <-l.fail:
		return nil, err
	case <-l.done:
		return nil, net.ErrClosed
	}
}

func (l *bothProtocols) Close() error {
	l.once.Do(func() { close(l.done) })
	return l.inner.Close()
}

func (l *bothProtocols) Addr() net.Addr { return l.inner.Addr() }

// replayConn is a connection whose first byte has already been read, so the
// next reader still sees a whole request.
type replayConn struct {
	net.Conn
	reader io.Reader
}

func (c *replayConn) Read(b []byte) (int, error) { return c.reader.Read(b) }
