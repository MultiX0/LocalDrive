# Notes for coding agents: the server

Local rules for `server/`. The root [`AGENTS.md`](../AGENTS.md) covers
everything general and is not repeated here.

This binary is the product. It holds the only copy of the user's data, so the
bar for a change here is higher than anywhere else in the repository.

## Layers, and what belongs in each

A request travels through these in order. Putting logic in the wrong one is the
most common structural mistake here.

| Package | Owns | Must not |
| --- | --- | --- |
| `internal/httpapi` | Routing, decoding, status codes, the error envelope | Decide whether the caller is allowed |
| `internal/files`, `auth`, `shares`, `libraries`, `settings` | The rules. Permission decisions, validation, domain errors | Know about `http` |
| `internal/storage`, `uploads` | Bytes on disk, content addressing | Know who is asking |
| `internal/db` | Connection, migrations, queries | Hold business rules |
| `internal/app` | Wiring the above together | Contain logic worth testing on its own |
| `internal/runner` | The CLI, setup, service install, update | Be reachable from a request |

**Authorisation is decided in the domain package, never in a handler.**
`files.Require` returns `ErrForbidden`, and the handler's job is only to turn
that into a 403. A handler that inspects a role and decides for itself has
moved a security decision somewhere it will not be found again.

## Errors

Domain packages export sentinel errors and wrap with `%w`. Handlers call
`a.fail(w, r, err)` and let `internal/httpapi/respond.go` do the mapping.

Do not write a status code and a message inline in a handler. One envelope,
one place that maps errors onto it, which is what keeps the wording consistent
across an API that clients parse.

A new domain error needs a case in `fail`. Without one it becomes a 500.

## The API is a contract

`localdrive/` and every share link depend on it. Response shapes, field names,
status codes and error `code` strings are public.

Add fields rather than renaming them. If something has to change
incompatibly, say so explicitly in the change summary and update
`docs/api-reference/`.

## Database

Migrations are numbered SQL files in `migrations/`, embedded into the binary
and applied in filename order by `internal/db/migrate.go`. They run on start.

- **Never edit a migration that has shipped.** It has already run on somebody's
  machine and will not run again. Add a new numbered file.
- Migrations must be safe to run on a database that is already live, and safe
  to run twice.
- The database is SQLite through a pure Go driver. No CGO, ever. That is what
  keeps the binary a single file.

## Files and paths

Anything that turns a user supplied name into a filesystem path goes through
`pkg/pathsafe`. There is no exception worth making. Path traversal is the
highest severity bug this project can have, because the process can read the
whole disk and the caller chose the name.

Storage is content addressed. The backing directory belongs to the server, and
nothing outside it may assume a layout.

## Concurrency

Uploads are resumable and clients retry, so handlers must tolerate the same
request arriving twice. `internal/httpapi/idempotency.go` exists for that.

Run the tests with the race detector, which is what CI does:

```
go test -race -count=1 ./...
```

A test that only fails under `-race` is a real bug, not a flaky test.

## Logging

`log/slog`, structured, key value pairs. The first line at startup prints the
resolved configuration, which is how people find out where their data went, so
do not remove it.

Never log a password, a token, a session id or a file's contents. Paths and
account ids are acceptable.

## Running it

```
go run ./cmd/localdrive serve
```

`serve` is the foreground mode with no Docker. The other modes are in
`internal/runner`; `docs/self-hosting/cli.mdx` documents all of them and is the
place to check what output is expected, because that page was captured from
real runs.

Behaviour differs between Docker and the bare binary in several places. Decide
which one you are testing before concluding anything.

## Before you finish

```
gofmt -l .
go vet ./...
go test -race -count=1 ./...
```

Add a test when behaviour changed. `internal/app` holds the integration tests
that drive the real HTTP surface through a harness, and that is usually the
right place for anything spanning more than one package.
