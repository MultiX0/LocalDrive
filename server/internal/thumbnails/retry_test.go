package thumbnails

import (
	"testing"
	"time"
)

// A single attempt was the bug. A server that came up while the network was
// still settling gave up for the life of the process, and every video uploaded
// afterwards had no preview until somebody restarted it.
func TestTheBackoffGrowsAndIsBounded(t *testing.T) {
	if len(fetchBackoff) < 4 {
		t.Fatalf("only %d attempts, which is not a retry policy", len(fetchBackoff))
	}
	for i := 1; i < len(fetchBackoff); i++ {
		if fetchBackoff[i] <= fetchBackoff[i-1] {
			t.Fatalf("gap %d (%s) is not longer than gap %d (%s): retrying at a "+
				"fixed rate hammers a host that is already struggling",
				i, fetchBackoff[i], i-1, fetchBackoff[i-1])
		}
	}
	if first := fetchBackoff[0]; first > time.Minute {
		t.Errorf("first retry waits %s, which is too long to notice a blip", first)
	}
	if last := fetchBackoff[len(fetchBackoff)-1]; last < time.Hour {
		t.Errorf("last retry waits %s, so it gives up too eagerly", last)
	}
}

// Retries have to be scattered. Servers that all lost power together come back
// together, and a fixed schedule would send every one of them at the same host
// in the same second.
func TestRetriesAreScattered(t *testing.T) {
	const base = time.Minute
	seen := map[time.Duration]bool{}
	for i := 0; i < 200; i++ {
		got := jitter(base)
		if got < base {
			t.Fatalf("jitter produced %s, which is shorter than the base %s", got, base)
		}
		if got > base+base/3+time.Millisecond {
			t.Fatalf("jitter produced %s, more than a third above the base %s", got, base)
		}
		seen[got] = true
	}
	if len(seen) < 50 {
		t.Fatalf("only %d distinct delays out of 200, which is not spread out", len(seen))
	}
}

// A zero or tiny duration must not panic on the modulo.
func TestJitterHandlesTinyDurations(t *testing.T) {
	for _, d := range []time.Duration{0, 1, 2, time.Nanosecond} {
		if got := jitter(d); got < d {
			t.Fatalf("jitter(%s) = %s, which went backwards", d, got)
		}
	}
}
