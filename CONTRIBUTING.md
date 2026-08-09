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

## What makes a change easy to accept

- **One thing.** A pull request that fixes a bug and reformats a file is two
  reviews wearing a coat.
- **A reason in the description.** What was wrong, and what it does now.
- **Matching the surrounding code.** Naming, structure and comment density are
  reasonably consistent already; follow whatever the file you are in does.
- **Tests when the change is behavioural.** Not for a copy edit.

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

## Licence

Contributions are under the [MIT licence](LICENSE), same as the project. By
opening a pull request you are agreeing to that. There is no CLA.
