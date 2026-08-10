# Notes for coding agents

Context for an AI assistant working in this repository. Humans may find it
useful too, but the audience is a model with no memory of the last session.

Read this file first. Then read the `AGENTS.md` nearest the code you are about
to change: [`server/`](server/AGENTS.md), [`localdrive/`](localdrive/AGENTS.md),
[`docs/`](docs/AGENTS.md), [`landing/`](landing/AGENTS.md). Those hold local
rules only and do not repeat what is here.

For **why** the project makes the choices it does, and for judging whether a
change belongs at all, read [`VISION.md`](VISION.md). This file is how to work.
That one is what to work towards.

## What this is

Local Drive is a self hosted alternative to Google Drive. Two parts:

- `server/` is a Go binary. **This is the product.** It holds the data, serves
  the API, and runs on its own.
- `localdrive/` is a Flutter client for Android, Windows, Linux, macOS, iOS and
  the web. It is an interface to the server and holds nothing the server does
  not.

Also `docs/` (the single source for all documentation) and `landing/` (a
Next.js site that reads `docs/` directly at build time).

Machine readable facts about commands, paths and components are in
[`.ai/project.json`](.ai/project.json). Prefer it over guessing, and update it
when the thing it describes changes.

## The loop

Work in this order. Most bad changes come from starting at step 4.

1. **Discover.** Find the code that already owns this behaviour. Search before
   creating. A second implementation beside an existing one is the most
   expensive mistake available here.
2. **Understand.** Read the surrounding package and its tests. Check `docs/`
   for the documented behaviour, which is the contract.
3. **Plan.** Decide the smallest change that solves it. Note what could break.
4. **Implement.** Match the file you are editing.
5. **Test.** Run the checks below. Add a test when behaviour changed.
6. **Review.** Reread your own diff as a reviewer would. Remove anything that
   is not part of the stated change.
7. **Document.** Update `docs/` when user visible behaviour changed.
8. **Verify.** Run the checks again, on the final state of the tree.
9. **Summarise.** Say what changed, what you ran, what passed, what failed and
   what you could not determine.

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

**When the change is user visible, prove it against something running.** The
end-to-end layer runs on TestSprite, and the judgement about when it is worth
the cost is in [`.ai/skills/verify-with-testsprite.md`](.ai/skills/verify-with-testsprite.md).
It cannot reach `localhost`, so a change that is only on this machine cannot be
verified there — say that rather than pointing it at an older deployment. The
checks above still come first, and still catch more per second spent.

**Verify before claiming.** Do not report a command as working without running
it. Several things in this project behave differently under Docker and as the
bare binary, and guessing which is which produces documentation that fails for
the reader.

**Report what you could not do.** A change that says "I could not run the
Flutter tests, no SDK on this machine" is useful. The same change claiming they
passed is not, and it costs the reviewer their trust in the rest of it.

## Never

- Commit a secret, a key, a keystore or a `.env`. Check `.gitignore` before
  adding anything that looks like credentials.
- Bypass an authorisation check, or add an admin path that reads another
  account's files.
- Weaken, skip or delete a test to make a build pass. A failing test is a
  finding, not an obstacle.
- Claim a test passed without running it, or hide a failure in a summary.
- Change the licence, the security policy or the code of conduct.
- Change API responses, CLI output, database schema or on-disk layout as a side
  effect of something else. Those are public contracts. See
  [Changing something public](#changing-something-public).
- Delete user data, or write a migration that cannot be reversed, without being
  asked in those words.
- Refactor code that is not part of the task.

## Always

- Search for the existing implementation first.
- Keep the diff scoped to what was asked.
- Prefer the smallest change that is actually correct.
- Add a test when you change behaviour.
- Update documentation when you change what a user sees.
- Say plainly what you are unsure about.

## Decisions that look like bugs and are not

Change these only with a clear instruction, because each one has a reason that
is not visible from the code alone.

- **Plain HTTP is the default.** No certificate authority issues certificates
  for a LAN IP, and a self signed certificate makes the app refuse to connect
  outright. HTTPS turns on when `LD_DOMAIN` is set. The configured port then
  answers both protocols, because a certificate covers the domain and can never
  cover an address. See `docs/self-hosting/https.mdx`.
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
- **A new device is held for approval, unless the login carried a correct TOTP
  code.** A code from the enrolled authenticator already proves it is the same
  person, and asking again from a device they may no longer own turns a lost
  phone into a locked account. Approval still applies to every login without a
  second factor.

## Changing something public

The API, the CLI surface and its output, the database schema, the on-disk
layout and the configuration keys are contracts. Something outside this
repository depends on each of them.

Before changing one:

1. Find every caller. For the API that includes `localdrive/` and any share
   link. For the CLI it includes `docs/self-hosting/cli.mdx` and the service
   units written by `localdrive service`.
2. Decide whether the old form keeps working. Prefer adding over changing.
3. Update the documentation in the same change, not afterwards.
4. Say in your summary that a public contract moved, and what depends on it.

## When you are stuck

In order:

1. Read more of the repository. Most questions here are answered by a file
   somewhere, usually in `docs/` or a test.
2. Check `git log` for the file. Several decisions are explained in a commit
   message and nowhere else.
3. If it still cannot be determined, **write down the uncertainty and continue
   with the parts that do not depend on it.** Do not guess and present the
   guess as fact.
4. Stop and ask only when proceeding either way could destroy data, weaken
   security, or produce a change that would have to be thrown away entirely.

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
.ai/                   machine readable project facts, and task playbooks
```

## Releasing

Push a bare version tag such as `0.0.1`. The workflow builds everything and
names the assets exactly what the website looks for. The filenames are load
bearing; see `docs/contributing/releasing.mdx` before changing one.
