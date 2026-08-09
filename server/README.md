# Local Drive, the server

The Go backend for [Local Drive](../README.md). One binary, several modes.

Clone this to run your own instance. The client lives in
[`../localdrive`](../localdrive), and the full documentation in
[`../docs`](../docs).

## Running it

```
go run ./cmd/localdrive           # setup, since there is no argument
go run ./cmd/localdrive serve     # the API, in the foreground
go run ./cmd/localdrive help      # everything it can do
```

Or build it and hand the executable to someone who has never used Docker:

```
go build -o localdrive ./cmd/localdrive
```

Full walkthrough: [Quick start](../docs/getting-started/quick-start.mdx).

## Modes

| Mode | Who runs it |
| --- | --- |
| `setup` | a person, once |
| `serve` | the container, or the machine directly |
| `start`, `stop`, `restart`, `status`, `logs` | a person, day to day |
| `reset-admin`, `backup` | a person, when needed |
| `mount-helper` | its own container, the only privileged one |
| `lan-discovery` | its own container, the only one with host networking |
| `healthcheck` | the container's own HEALTHCHECK |

All the same executable. That does not weaken the privilege separation: the
boundary is the process and the container it runs in, not the file on disk.

## Layout

```
cmd/localdrive/     the one entry point
internal/
  runner/           every mode, plus install location and file rendering
  config/           environment loading and validation, all of it at startup
  httpapi/          chi routes and handlers, HTTP translation only
  auth/             passwords, tokens, sessions, invites, 2fa, recovery marker
  files/            the node tree, access resolution, maintenance passes
  shares/           public links and account to account grants
  libraries/        storage roots, live disk stats, offline detection
  storage/          the content addressed object store and the browse mirror
  uploads/          the tus DataStore
  thumbnails/       generator dispatch and capability probing
  ws/               the hub, clients, event types
  jobs/             worker pool and scheduler
  db/               sqlite setup, migrations, the writer goroutine
  audit/            the activity log
  middleware/       recovery, logging, cors, rate limiting
  models/           row shapes shared by every package
pkg/
  pathsafe/         canonicalization and traversal guard, tested in isolation
  checksum/
migrations/         embedded, applied in order at startup
scripts/            host level automount, and a shell backup
```

## Checks

```
go test ./...
go vet ./...
govulncheck ./...
```

The integration suite spins the whole server up against a temporary SQLite file
and a temporary directory and exercises the real HTTP handlers: the permission
matrix, admin not being able to read a member's files, trash hiding shared
items, share expiry, resumable upload reassembly, deduplication surviving a
delete, quota refusal at creation time, idempotency replay, path traversal, and
the device approval state machine.

## Generated files

`Caddyfile` and `docker-compose.yml` are generated from the same renderers the
setup tool uses, so the two can never drift apart and neither contains a
placeholder domain for anyone to trip over.

```
go run gen_defaults.go
```

## Two things worth knowing

**Storage is content addressed.** Every file lives once at
`objects/<aa>/<bb>/<sha256>`, written to a temp path and renamed into place. A
rename or a move is a metadata update; no bytes move. Because of that,
dropping a file into the backing directory from outside is unsupported, the
same way you cannot add a file to Google Drive by writing into its bucket. A
symlink mirror at `browse/` keeps the drive readable in a file manager.

**Nodes inherit their owner from their parent.** A file an editor uploads into
your folder belongs to you and counts against your quota. Google Drive gives it
to the uploader; inheriting keeps quota accounting and the access walk coherent
for a household server.

## Reference

- [Backend architecture](../docs/architecture/backend.mdx)
- [Security](../docs/architecture/security.mdx)
- [Environment variables](../docs/self-hosting/environment-variables.mdx)
- [Endpoints](../docs/api-reference/endpoints.mdx)
