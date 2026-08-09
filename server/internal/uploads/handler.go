package uploads

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"regexp"
	"strings"

	"github.com/tus/tusd/v2/pkg/handler"

	"github.com/MultiX0/LocalDrive/server/internal/files"
	"github.com/MultiX0/LocalDrive/server/internal/models"
)

// HeaderNodeID carries the committed node's id back on the final response, so
// a client knows what its upload became without a second request.
const HeaderNodeID = "Local-Drive-Node-Id"

// HandlerDeps is what the tus handler needs from the rest of the server.
type HandlerDeps struct {
	Store       *Store
	Files       *files.Service
	Log         *slog.Logger
	BasePath    string
	MaxSize     int64
	UserID      func(ctx context.Context) (string, bool)
	ClientIP    func(ctx context.Context) string
	CORSOrigins []string
}

// NewHandler builds the routed tus handler with the two callbacks that make
// an upload safe: one that refuses before any bytes are accepted, and one that
// commits before the client is told it succeeded.
func NewHandler(d HandlerDeps) (*handler.Handler, error) {
	composer := handler.NewStoreComposer()
	d.Store.UseIn(composer)

	log := d.Log
	if log == nil {
		log = slog.Default()
	}

	cors := &handler.CorsConfig{
		Disable:          len(d.CORSOrigins) == 0,
		AllowOrigin:      originPattern(d.CORSOrigins),
		AllowCredentials: false,
		AllowMethods:     "POST, HEAD, PATCH, DELETE, OPTIONS",
		AllowHeaders: "Authorization, Content-Type, Upload-Length, Upload-Offset, Tus-Resumable, " +
			"Upload-Metadata, Upload-Defer-Length, Upload-Concat, Idempotency-Key",
		ExposeHeaders: "Upload-Offset, Location, Upload-Length, Tus-Version, Tus-Resumable, " +
			"Tus-Max-Size, Tus-Extension, Upload-Metadata, Upload-Defer-Length, " + HeaderNodeID,
		MaxAge: "86400",
	}

	return handler.NewHandler(handler.Config{
		StoreComposer:           composer,
		BasePath:                d.BasePath,
		MaxSize:                 d.MaxSize,
		DisableDownload:         true,
		RespectForwardedHeaders: true,
		Cors:                    cors,

		PreUploadCreateCallback: func(hook handler.HookEvent) (handler.HTTPResponse, handler.FileInfoChanges, error) {
			userID, ok := d.UserID(hook.Context)
			if !ok {
				return handler.HTTPResponse{}, handler.FileInfoChanges{},
					handler.NewError("ERR_UNAUTHORIZED", "sign in first", http.StatusUnauthorized)
			}
			meta := hook.Upload.MetaData
			name := strings.TrimSpace(meta[MetaFilename])
			if name == "" {
				return handler.HTTPResponse{}, handler.FileInfoChanges{},
					handler.NewError("ERR_NO_FILENAME", "the upload needs a filename", http.StatusBadRequest)
			}
			libraryID, ownerID, err := d.Files.PrepareUpload(
				hook.Context, userID, meta[MetaParentID], meta[MetaNodeID], hook.Upload.Size)
			if err != nil {
				return handler.HTTPResponse{}, handler.FileInfoChanges{}, translate(err)
			}
			next := handler.MetaData{}
			for k, v := range meta {
				next[k] = v
			}
			next[MetaLibraryID] = libraryID
			next[MetaOwnerID] = ownerID
			return handler.HTTPResponse{}, handler.FileInfoChanges{MetaData: next}, nil
		},

		PreFinishResponseCallback: func(hook handler.HookEvent) (handler.HTTPResponse, error) {
			userID, ok := d.UserID(hook.Context)
			if !ok {
				return handler.HTTPResponse{},
					handler.NewError("ERR_UNAUTHORIZED", "sign in first", http.StatusUnauthorized)
			}
			raw, err := d.Store.GetUpload(hook.Context, hook.Upload.ID)
			if err != nil {
				return handler.HTTPResponse{}, err
			}
			u, ok := raw.(*upload)
			if !ok {
				return handler.HTTPResponse{}, errors.New("uploads: unexpected upload type")
			}
			sum, err := u.Checksum()
			if err != nil {
				return handler.HTTPResponse{}, err
			}
			binPath, infoPath := u.Paths()
			meta := hook.Upload.MetaData

			node, err := d.Files.CommitUpload(hook.Context, files.CommitUploadParams{
				UserID:   userID,
				ParentID: meta[MetaParentID],
				NodeID:   meta[MetaNodeID],
				Name:     strings.TrimSpace(meta[MetaFilename]),
				MimeType: normalizeMime(meta[MetaFiletype], meta[MetaFilename]),
				Size:     hook.Upload.Size,
				Checksum: sum,
				TempPath: binPath,
				IP:       d.ClientIP(hook.Context),
			})
			if err != nil {
				return handler.HTTPResponse{}, translate(err)
			}

			// the bytes are only adopted once the row exists, and the staging
			// metadata goes with them
			if err := d.Files.AdoptObject(node.LibraryID, binPath, sum); err != nil {
				log.Error("adopting uploaded object failed", "node", node.ID, "error", err)
				return handler.HTTPResponse{}, err
			}

			// only now, with the bytes actually in storage. Queued any earlier
			// these read an object that does not exist yet and fail for good
			d.Files.ScheduleDerived(node)
			if err := os.Remove(infoPath); err != nil && !os.IsNotExist(err) {
				log.Debug("upload info cleanup failed", "path", infoPath, "error", err)
			}

			return handler.HTTPResponse{
				Header: handler.HTTPHeader{HeaderNodeID: node.ID},
			}, nil
		},
	})
}

// translate maps a files error onto the tus error shape so a client sees a
// useful status rather than a blanket 500.
func translate(err error) error {
	switch {
	case errors.Is(err, files.ErrNotFound):
		return handler.NewError("ERR_NOT_FOUND", "that folder does not exist", http.StatusNotFound)
	case errors.Is(err, files.ErrForbidden):
		return handler.NewError("ERR_FORBIDDEN", "you cannot add to that folder", http.StatusForbidden)
	case errors.Is(err, files.ErrQuota):
		return handler.NewError("ERR_QUOTA", "not enough space left in this account", http.StatusInsufficientStorage)
	case errors.Is(err, files.ErrInvalidName):
		return handler.NewError("ERR_INVALID_NAME", "that filename cannot be used", http.StatusBadRequest)
	case errors.Is(err, files.ErrNotAFolder):
		return handler.NewError("ERR_NOT_A_FOLDER", "the destination is not a folder", http.StatusBadRequest)
	case errors.Is(err, files.ErrNotAFile):
		return handler.NewError("ERR_NOT_A_FILE", "that node is not a file", http.StatusBadRequest)
	default:
		return err
	}
}

// normalizeMime prefers what the client declared, falling back to the
// extension so a file uploaded with no type still gets a badge and a preview.
func normalizeMime(declared, filename string) string {
	declared = strings.TrimSpace(strings.ToLower(declared))
	if declared != "" && declared != "application/octet-stream" {
		return declared
	}
	if guessed := models.MimeFromName(filename); guessed != "" {
		return guessed
	}
	if declared != "" {
		return declared
	}
	return "application/octet-stream"
}

func originPattern(origins []string) *regexp.Regexp {
	if len(origins) == 0 {
		return regexp.MustCompile("^$")
	}
	parts := make([]string, 0, len(origins))
	for _, o := range origins {
		parts = append(parts, regexp.QuoteMeta(strings.TrimSuffix(o, "/")))
	}
	return regexp.MustCompile("^(" + strings.Join(parts, "|") + ")$")
}
