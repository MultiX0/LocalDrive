// Package migrations holds the schema, embedded into the binary so a
// deployment never needs the .sql files on disk next to it.
package migrations

import "embed"

// FS holds every numbered migration, applied in filename order.
//
//go:embed *.sql
var FS embed.FS
