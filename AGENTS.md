# Notes for coding agents

Context for an AI assistant working in this repository. Humans may find it
useful too, but the audience is a model with no memory of the last session.

## What this is

Local Drive is a self hosted alternative to Google Drive. Two parts:

- `server/` is a Go binary. **This is the product.** It holds the data, serves
  the API, and runs on its own.
- `localdrive/` is a Flutter client for Android, Windows, Linux, macOS, iOS and
  the web. It is an interface to the server and holds nothing the server does
  not.

Also `docs/` (the single source for all documentation) and `landing/` (a
Next.js site that reads `docs/` directly at build time).

## Ground rules

**Do not add dependencies without being asked.** The server builds with
`CGO_ENABLED=0` and a pure Go SQLite driver so it stays one file with no
runtime. A dependency that breaks that trades away the main thing the project
offers.

**Do not restate documentation in a second place.** `docs/` is the source.
README files link to it. If two files describe the same behaviour, one of them
is already wrong.

**Run the checks.** They are fast and they catch real things:

```
cd server     && go test ./... && go vet ./...
cd localdrive && flutter analyze && flutter test
cd landing    && npm run build
```

The landing build parses every documentation file and fails on an internal
link that does not resolve. It is the link checker.

**Verify before claiming.** Do not report a command as working without running
it. Several things in this project behave differently under Docker and as the
bare binary, and guessing which is which produces documentation that fails for
the reader.

## Decisions that look like bugs and are not

Change these only with a clear instruction, because each one has a reason that
is not visible from the code alone.

- **Plain HTTP is the default.** No certificate authority issues certificates
  for a LAN IP, and a self signed certificate makes the app refuse to connect
  outright. HTTPS turns on when `LD_DOMAIN` is set. See
  `docs/self-hosting/https.mdx`.
- **`.env` holds host paths. `docker-compose.yml` pins container paths.**
  Compose `environment` overrides `env_file`, which is what lets one `.env` be
  correct in both modes. Writing container paths into `.env` sends a bare
  `serve` to `/data` on the host.
- **No shadows and no gradients anywhere in the UI.** Flat fills with a 1px
  border. This is a design decision, not an oversight.
- **Exactly two accent colours**, `#4C8DFF` and `#EE7759`. The file type
  colours are semantic and must not be used decoratively.
- **Admin is not a master key.** An admin manages the server and cannot
  silently read another account's files. Do not add a bypass for convenience.
- **New devices need approval by default.** A password alone is not access.

## Style

Match the file you are editing. Beyond that:

- Comments explain **why**, not what. If a comment restates the line below it,
  delete it. Most functions do not need one.
- Plain sentences. No marketing language, no exclamation marks.
- Go: `gofmt`. Dart: `dart format`, `///` for public API documentation and `//`
  for everything else. TypeScript: `prettier`.
- Documentation is CommonMark parsed as markdown, not MDX. Internal links have
  no file extension.

## Layout

```
server/
  cmd/localdrive/      the entry point, one binary, several modes
  internal/app/        http handlers and routing
  internal/runner/     the cli: setup, init, serve, status, update
  internal/updater/    self update against GitHub releases
localdrive/
  lib/core/            theme, router, services, shared widgets
  lib/features/        one directory per feature, ui and controllers together
docs/                  every documentation page
landing/               the website, reads ../docs and ../LICENSE
```

## Releasing

Push a bare version tag such as `0.0.1`. The workflow builds everything and
names the assets exactly what the website looks for. The filenames are load
bearing; see `docs/contributing/releasing.mdx` before changing one.
