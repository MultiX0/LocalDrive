package files

import (
	"context"
	"database/sql"
	"time"

	"github.com/MultiX0/LocalDrive/server/internal/db"
	"github.com/MultiX0/LocalDrive/server/internal/models"
	"github.com/MultiX0/LocalDrive/server/internal/storage"
)

// PurgeTrash permanently deletes anything that has sat in the trash past the
// retention policy. It reuses the normal delete path so objects are released
// with the same reference check.
func (s *Service) PurgeTrash(ctx context.Context, retentionDays int) error {
	if retentionDays <= 0 {
		return nil
	}
	cutoff := db.NowMillis() - int64(retentionDays)*24*60*60*1000
	rows, err := s.database.Read().QueryContext(ctx, `
		SELECT n.id, n.owner_id FROM nodes n
		LEFT JOIN nodes parent ON parent.id = n.parent_id
		WHERE n.deleted_at IS NULL AND n.trashed_at IS NOT NULL AND n.trashed_at < ?
		  AND (parent.id IS NULL OR parent.trashed_at IS NULL)
		LIMIT 200`, cutoff)
	if err != nil {
		return err
	}
	type victim struct{ id, owner string }
	var list []victim
	for rows.Next() {
		var v victim
		if err := rows.Scan(&v.id, &v.owner); err != nil {
			rows.Close()
			return err
		}
		list = append(list, v)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return err
	}
	for _, v := range list {
		if err := s.PermanentDelete(ctx, v.owner, v.id, ""); err != nil {
			s.log.Warn("trash purge could not delete an item", "node", v.id, "error", err)
		}
	}
	return nil
}

// PruneVersions drops history past the retention policy, keeping at least the
// configured count and never touching a version another node still uses.
func (s *Service) PruneVersions(ctx context.Context, keepCount, keepDays int) error {
	if keepCount <= 0 && keepDays <= 0 {
		return nil
	}
	cutoff := db.NowMillis() - int64(keepDays)*24*60*60*1000

	rows, err := s.database.Read().QueryContext(ctx, `
		SELECT v.id, v.node_id, v.checksum_sha256, n.library_id
		FROM node_versions v JOIN nodes n ON n.id = v.node_id
		WHERE n.deleted_at IS NULL
		  AND (
		    v.created_at < ?
		    OR (SELECT COUNT(*) FROM node_versions newer
		         WHERE newer.node_id = v.node_id AND newer.created_at > v.created_at) >= ?
		  )
		LIMIT 500`, cutoff, keepCount)
	if err != nil {
		return err
	}
	type stale struct{ id, nodeID, sum, libraryID string }
	var list []stale
	for rows.Next() {
		var v stale
		if err := rows.Scan(&v.id, &v.nodeID, &v.sum, &v.libraryID); err != nil {
			rows.Close()
			return err
		}
		list = append(list, v)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return err
	}
	if len(list) == 0 {
		return nil
	}

	var release []orphanObject
	err = s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		for _, v := range list {
			if _, err := tx.ExecContext(ctx, `DELETE FROM node_versions WHERE id = ?`, v.id); err != nil {
				return err
			}
			var stillUsed int
			err := tx.QueryRowContext(ctx, `
				SELECT (SELECT COUNT(*) FROM nodes WHERE checksum_sha256 = ? AND library_id = ? AND deleted_at IS NULL)
				     + (SELECT COUNT(*) FROM node_versions ver JOIN nodes n ON n.id = ver.node_id
				         WHERE ver.checksum_sha256 = ? AND n.library_id = ?)`,
				v.sum, v.libraryID, v.sum, v.libraryID).Scan(&stillUsed)
			if err != nil {
				return err
			}
			if stillUsed == 0 {
				release = append(release, orphanObject{LibraryID: v.libraryID, Checksum: v.sum})
			}
		}
		return nil
	})
	if err != nil {
		return err
	}
	s.releaseObjects(release)
	s.log.Info("pruned old versions", "count", len(list), "objects_released", len(release))
	return nil
}

// RecalculateQuotas rebuilds every account's running usage counter. Normal
// operation keeps the counter current transactionally; this is the periodic
// correctness check behind it.
func (s *Service) RecalculateQuotas(ctx context.Context) error {
	return s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		_, err := tx.ExecContext(ctx, `
			UPDATE users SET quota_bytes_used = COALESCE((
				SELECT SUM(size_bytes) FROM nodes
				WHERE nodes.owner_id = users.id AND nodes.type = 'file' AND nodes.deleted_at IS NULL
			), 0), updated_at = ?`, db.NowMillis())
		return err
	})
}

// IntegrityReport is what the periodic check found.
type IntegrityReport struct {
	Checked  int
	Missing  []string
	Mismatch []string
	At       time.Time
}

// VerifyIntegrity confirms every object the database references is really on
// disk with a matching checksum, and flags the library rather than surfacing a
// confusing per-file error later.
func (s *Service) VerifyIntegrity(ctx context.Context) error {
	list, err := s.libs.List(ctx)
	if err != nil {
		return err
	}
	for _, lib := range list {
		if !lib.Online() {
			continue
		}
		report, err := s.verifyLibrary(ctx, lib)
		if err != nil {
			s.log.Warn("integrity check failed", "library", lib.Name, "error", err)
			continue
		}
		if len(report.Missing) > 0 || len(report.Mismatch) > 0 {
			s.log.Error("this library needs attention",
				"library", lib.Name,
				"checked", report.Checked,
				"missing", len(report.Missing),
				"mismatched", len(report.Mismatch))
		} else {
			s.log.Info("integrity check clean", "library", lib.Name, "checked", report.Checked)
		}
	}
	return nil
}

func (s *Service) verifyLibrary(ctx context.Context, lib models.Library) (IntegrityReport, error) {
	report := IntegrityReport{At: time.Now()}
	rows, err := s.database.Read().QueryContext(ctx, `
		SELECT id, checksum_sha256 FROM nodes
		WHERE library_id = ? AND type = 'file' AND deleted_at IS NULL AND checksum_sha256 IS NOT NULL
		ORDER BY updated_at DESC LIMIT 2000`, lib.ID)
	if err != nil {
		return report, err
	}
	defer rows.Close()
	for rows.Next() {
		var id, sum string
		if err := rows.Scan(&id, &sum); err != nil {
			return report, err
		}
		report.Checked++
		exists, _, err := s.store.Exists(lib.RootPath, sum)
		if err != nil {
			return report, err
		}
		if !exists {
			report.Missing = append(report.Missing, id)
			continue
		}
		if err := s.store.Verify(lib.RootPath, sum); err != nil {
			if err == storage.ErrNotFound {
				report.Missing = append(report.Missing, id)
			} else {
				report.Mismatch = append(report.Mismatch, id)
			}
		}
		select {
		case <-ctx.Done():
			return report, ctx.Err()
		default:
		}
	}
	return report, rows.Err()
}
