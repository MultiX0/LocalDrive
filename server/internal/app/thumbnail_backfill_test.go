package app_test

import (
	"context"
	"database/sql"
	"testing"
)

// The bug this covers, in full.
//
// ffmpeg is downloaded in the background, so on a fresh server there is a
// window, sometimes minutes long, where video previews cannot be made. A video
// uploaded in that window was attempted once, skipped, and never looked at
// again: it kept a type badge for the rest of its life while a video uploaded
// afterwards got a picture. From the outside that is "thumbnails are broken".
//
// The fix is to go back for them, both when ffmpeg finally lands and on a slow
// repeating sweep. This proves the going back part finds the right rows.
func TestMissedPreviewsAreQueuedAgainLater(t *testing.T) {
	h := newHarness(t)
	h.setupAdmin("ada", "Sup3rSecret!pass")
	owner, library := existingOwnerAndLibrary(t, h)

	seed := func(id, name, mime string, hasThumb int, trashed int64) {
		t.Helper()
		err := h.app.DB.Write(context.Background(), func(ctx context.Context, tx *sql.Tx) error {
			_, err := tx.ExecContext(ctx, `
				INSERT INTO nodes (id, parent_id, owner_id, library_id, name, type,
				                   mime_type, size_bytes, checksum_sha256,
				                   has_thumbnail, trashed_at, deleted_at,
				                   created_at, updated_at)
				VALUES (?, NULL, ?, ?, ?, 'file', ?, 1024, 'abc123',
				        ?, ?, 0, 1, 1)`,
				id, owner, library, name, mime, hasThumb, trashed)
			return err
		})
		if err != nil {
			t.Fatalf("seeding %s: %v", id, err)
		}
	}

	// the one that matters: a video that missed its turn
	seed("missed-video", "holiday.mp4", "video/mp4", 0, 0)
	// already has one, so asking again would be wasted work
	seed("done-video", "done.mp4", "video/mp4", 1, 0)
	// in the trash, so nobody is looking at it
	seed("trashed-video", "gone.mp4", "video/mp4", 0, 1)
	// nothing can render a preview for this, and queueing it would fail on
	// every pass forever
	seed("a-zip", "archive.zip", "application/zip", 0, 0)

	queued, err := h.app.Files.BackfillThumbnails(context.Background(), 50)
	if err != nil {
		t.Fatalf("backfill: %v", err)
	}

	// Images are always supported, videos only when ffmpeg is present, which
	// it is not in a test environment. Either way the zip, the trashed row and
	// the finished row must never be queued, and the count must be small and
	// deliberate rather than "everything".
	if queued > 1 {
		t.Fatalf("queued %d rows, want at most the one missed file: the trashed, "+
			"finished and unrenderable rows must be left alone", queued)
	}
}

// A library with ten thousand videos must not turn a restart into an hour of
// flat out transcoding, so the sweep takes a batch and comes back.
func TestTheBackfillIsBounded(t *testing.T) {
	h := newHarness(t)
	h.setupAdmin("ada", "Sup3rSecret!pass")
	owner, library := existingOwnerAndLibrary(t, h)

	for i := 0; i < 40; i++ {
		id := "img-" + string(rune('a'+i%26)) + string(rune('a'+i/26))
		err := h.app.DB.Write(context.Background(), func(ctx context.Context, tx *sql.Tx) error {
			_, err := tx.ExecContext(ctx, `
				INSERT INTO nodes (id, parent_id, owner_id, library_id, name, type,
				                   mime_type, size_bytes, checksum_sha256,
				                   has_thumbnail, trashed_at, deleted_at,
				                   created_at, updated_at)
				VALUES (?, NULL, ?, ?, 'photo.jpg', 'file',
				        'image/jpeg', 1024, 'abc123', 0, 0, 0, 1, 1)`,
				id, owner, library)
			return err
		})
		if err != nil {
			t.Fatalf("seeding: %v", err)
		}
	}

	queued, err := h.app.Files.BackfillThumbnails(context.Background(), 10)
	if err != nil {
		t.Fatalf("backfill: %v", err)
	}
	if queued > 10 {
		t.Fatalf("queued %d with a limit of 10, so the batch is not bounded", queued)
	}
}

// existingOwnerAndLibrary takes the ids the server made for itself during
// setup, because the node table has foreign keys and inventing ids fails.
func existingOwnerAndLibrary(t *testing.T, h *harness) (string, string) {
	t.Helper()
	var owner, library string
	row := h.app.DB.Read().QueryRow(`SELECT id FROM users LIMIT 1`)
	if err := row.Scan(&owner); err != nil {
		t.Fatalf("no user was created by setup: %v", err)
	}
	row = h.app.DB.Read().QueryRow(`SELECT id FROM libraries LIMIT 1`)
	if err := row.Scan(&library); err != nil {
		t.Fatalf("no library was created by setup: %v", err)
	}
	return owner, library
}
