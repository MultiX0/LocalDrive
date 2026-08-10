# End-to-end tests

The suite lives in [`testsprite/`](testsprite/). It drives a deployed server and
a real browser the way a person would. Start with
[TestSprite](../docs/contributing/testsprite.mdx) for how to install the CLI,
run it, and read a failure.

The tests at every other layer are in `server/internal/**/*_test.go` and
`localdrive/test/`, and they run locally with no account and no network. See
[Testing](../docs/contributing/testing.mdx) for what belongs where.

## Why here

End-to-end means a built server and a built client, driven together. It belongs
to neither component, so it lives beside both.

## Where it fits

```
unit  ->  integration  ->  api  ->  build  ->  environment  ->  end to end  ->  release
```

After a build has produced something to run, and before a release is treated as
good. It is the slowest and least specific layer, so it covers whole workflows.
Edge cases stay in the layers above, where a failure points at a line rather
than at a screen.

## The shape it should take

```
e2e/
  testsprite/
    frontend/   one plan per user workflow, in plain language
    backend/    one Python file per API contract, asserted over HTTP
    README.md   what each file covers, and what is still missing
```

## Requirements for whatever gets built here

These matter more than the choice of tool.

1. **A run starts from a known, disposable environment.** A fresh install, a
   fresh database, fixed fixtures. A suite that depends on state left by the
   previous run gets deleted within a year, because nobody can tell a real
   failure from a dirty environment.

2. **It runs against built artifacts.** The server binary and a built client,
   not `go run` and not `flutter run` against source. Testing what ships is the
   entire point of the layer.

3. **The repository stays complete without it.** No vendor is a dependency of
   this project. A contributor who cannot run the end-to-end suite must still
   be able to run everything else and send a pull request. Nothing in
   `server/`, `localdrive/`, `docs/` or the release process may come to depend
   on anything added here.

4. **A failure has to be diagnosable.** Capture the server log, the request
   that failed and a screenshot. An end-to-end failure that says only
   "expected true" costs more time than the test saves.

## What to cover first

The workflows where a person loses something, in order:

1. Sign up, sign in, and the second factor.
2. Upload a file, close the client, open it again, download it, and confirm the
   bytes match.
3. Interrupt an upload part way and resume it.
4. Share with another account, and confirm a third account is refused.
5. Trash, restore, and confirm versions survive.
6. Back up, destroy the install, restore, and confirm the files are there.
7. Update to a new version and confirm the server comes back on it.

Number 6 is the one worth building first. It is the promise the whole project
rests on, and it is the least likely to be caught by any test above this layer.
