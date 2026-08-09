package db

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"fmt"
	"io/fs"
	"sort"
	"strings"

	"github.com/MultiX0/LocalDrive/server/migrations"
)

const migrationTable = `
CREATE TABLE IF NOT EXISTS schema_migrations (
  name        TEXT PRIMARY KEY,
  checksum    TEXT NOT NULL,
  applied_at  INTEGER NOT NULL
)`

// Migrate applies every embedded migration that has not run yet, in filename
// order, each inside its own transaction on the writer goroutine.
func (d *DB) Migrate(ctx context.Context) error {
	if err := d.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		_, err := tx.ExecContext(ctx, migrationTable)
		return err
	}); err != nil {
		return fmt.Errorf("db: create migration table: %w", err)
	}

	entries, err := fs.Glob(migrations.FS, "*.sql")
	if err != nil {
		return err
	}
	sort.Strings(entries)

	applied := map[string]string{}
	rows, err := d.read.QueryContext(ctx, `SELECT name, checksum FROM schema_migrations`)
	if err != nil {
		return fmt.Errorf("db: read applied migrations: %w", err)
	}
	for rows.Next() {
		var name, sum string
		if err := rows.Scan(&name, &sum); err != nil {
			rows.Close()
			return err
		}
		applied[name] = sum
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return err
	}

	for _, name := range entries {
		body, err := migrations.FS.ReadFile(name)
		if err != nil {
			return err
		}
		sum := sha256.Sum256(body)
		hexSum := hex.EncodeToString(sum[:])

		if prev, ok := applied[name]; ok {
			if prev != hexSum {
				return fmt.Errorf("db: migration %s changed after it was applied, refusing to continue", name)
			}
			continue
		}

		statements := splitStatements(string(body))
		err = d.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
			for _, stmt := range statements {
				if _, err := tx.ExecContext(ctx, stmt); err != nil {
					return fmt.Errorf("statement %q: %w", firstLine(stmt), err)
				}
			}
			_, err := tx.ExecContext(ctx,
				`INSERT INTO schema_migrations (name, checksum, applied_at) VALUES (?, ?, ?)`,
				name, hexSum, NowMillis())
			return err
		})
		if err != nil {
			return fmt.Errorf("db: apply migration %s: %w", name, err)
		}
		d.log.Info("migration applied", "name", name)
	}
	return nil
}

// splitStatements breaks a migration file on semicolons at statement level.
// The schema deliberately contains no triggers or BEGIN blocks, so a simple
// split is correct here and is checked by the migration tests.
func splitStatements(body string) []string {
	var out []string
	for _, raw := range strings.Split(body, ";") {
		stmt := strings.TrimSpace(stripComments(raw))
		if stmt == "" {
			continue
		}
		out = append(out, stmt)
	}
	return out
}

func stripComments(s string) string {
	var b strings.Builder
	for _, line := range strings.Split(s, "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "--") {
			continue
		}
		b.WriteString(line)
		b.WriteString("\n")
	}
	return b.String()
}

func firstLine(s string) string {
	if i := strings.IndexByte(s, '\n'); i >= 0 {
		return strings.TrimSpace(s[:i])
	}
	return strings.TrimSpace(s)
}
