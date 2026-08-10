# Contributing

Thanks for looking. Bug reports, documentation fixes and small focused pull
requests are all genuinely useful.

The full guides live in [`docs/contributing/`](docs/contributing/) and are
rendered at [localdrive.iprog.dev/docs](https://localdrive.iprog.dev/docs).
This page is the short version.

## Before a large change

Open an issue first and describe what you want to do. This is not a formality:
a self hosted file server has a lot of surface, and some things that look like
obvious improvements are deliberate. It is much better to find that out in a
comment than after a weekend of work.

[VISION.md](VISION.md) is the fastest way to find out whether an idea fits
before you build it. It says what the project is trying to become, what it
refuses to become, and the questions a proposal gets judged against. The
section on what Local Drive is **not** has saved more time than the rest of it.

Small changes need no issue. Fix the typo, send the pull request.

## Getting it running

```
git clone https://github.com/MultiX0/LocalDrive
cd LocalDrive
```

The server, which is the part that matters:

```
cd server
go run ./cmd/localdrive serve
```

The client:

```
cd localdrive
flutter run
```

The website and rendered documentation:

```
cd landing
npm install
npm run dev
```

See [Development setup](docs/contributing/development-setup.mdx) for the
detail, including running against a real server from the app.

## Before opening a pull request

Everything CI runs, so nothing is a surprise:

```
cd server     && go test ./... && go vet ./...
cd localdrive && flutter analyze && flutter test
cd landing    && npm run build
```

The landing build is not optional even for a documentation change. It parses
every file in `docs/` and fails on a link that does not resolve, which is how
broken cross references get caught.

## Testing an application change

The checks above are the whole requirement, and they need no account anywhere.

Above them sits one more layer. Local Drive is tested end to end with
[TestSprite](https://www.testsprite.com/), which drives a real browser against a
running server. If your change affects a workflow somebody performs, signing in,
uploading, sharing, permissions, running it there catches the class of bug the
other layers cannot see.

It is **recommended, not required**. There is no TestSprite check in CI, no key
is needed to contribute, and a pull request is never blocked for not having run
it. Say what you ran and what you did not, and that is enough.

[Testing with TestSprite](docs/contributing/testsprite.mdx) covers installing
the CLI, authenticating, and reading a failure.

## What makes a change easy to accept

- **One thing.** A pull request that fixes a bug and reformats a file is two
  reviews wearing a coat.
- **A reason in the description.** What was wrong, and what it does now.
- **Matching the surrounding code.** Naming, structure and comment density are
  reasonably consistent already; follow whatever the file you are in does.
- **Tests when the change is behavioural.** Not for a copy edit.
  [Testing](docs/contributing/testing.mdx) covers which layer to write at. If
  the change touches permissions, paths, uploads or sharing, read
  [Security review](docs/contributing/security-review.mdx) first.

## Code style

Formatting is not a matter of taste here, it is a matter of running the tool:

```
cd server     && gofmt -w .
cd localdrive && dart format .
cd landing    && npx prettier --write .
```

On comments: explain why, not what. The code says what it does. A comment
earns its place by recording something the next person cannot see, usually a
constraint or a decision that looks wrong until you know the reason. Skip
comments that restate the line below them.

## Documentation

`docs/` is the single source. The website reads it directly, so there is
nothing to copy and nowhere for the two to disagree. Internal links are written
without a file extension and are checked at build time.

## Using an AI assistant

That is fine, and it is common here. The expectations are in
[AGENTS.md](AGENTS.md), and there are per-area rules in the `AGENTS.md` nearest
the code you are changing.

Two things are asked of anyone sending a change written with help from a model.
Understand the diff you are sending, because you will be asked about it in
review. And do not report a check as passing unless it was actually run: a
result nobody verified costs the reviewer their trust in the whole change,
including the parts that were fine.

## Licence

Contributions are under the [MIT licence](LICENSE), same as the project. By
opening a pull request you are agreeing to that. There is no CLA.
