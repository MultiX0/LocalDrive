# Skill: cutting a release

## Purpose

Ship a version whose artifacts the website and the self updater can both find.

## When to use

Publishing a new version. Not for ordinary merges.

## Required context

- `docs/contributing/releasing.mdx`, which is the authority. This skill is the
  order of operations, that page is the detail.
- `.github/workflows/release.yml`, which builds everything on a tag.

## Pre-flight

1. **Every check passes on the commit being tagged**, not on a similar one:

   ```
   cd server     && gofmt -l . && go vet ./... && go test -race -count=1 ./...
   cd localdrive && flutter analyze && flutter test
   cd landing    && npm run build
   ```

2. Documentation matches the behaviour being shipped. A release is where stale
   documentation becomes a support burden.
3. Any public contract that moved in this version is written down: API, CLI
   output, schema, on-disk layout, configuration keys.
4. Signing material is configured as repository secrets and is not in the tree.

## Workflow

1. Tag with a bare version, no `v` prefix:

   ```
   git tag 0.0.2
   git push origin 0.0.2
   ```

2. Watch the workflow. It builds the server for its published targets and the
   client for its published platforms.
3. **Do not rename an asset.** The filenames are load bearing: the website's
   download page and `localdrive update` both look for exact names. Renaming
   one silently breaks updating for everyone already installed.
4. Check the Android artifact is release signed rather than debug signed. The
   workflow asserts this, and the assertion exists because a debug signed build
   shipped once.
5. Write release notes that say what changed for a user, and name anything that
   requires action on their part.
6. **Install the artifact and run it** before treating the release as done.
   Download the published file, on a clean machine or container, and start it.

## Validation

After publishing:

- `localdrive update --check` on an older install finds the new version.
- The published checksums match the published binaries.
- The download page offers the new version.
- A fresh install of the published artifact starts and serves.

## Failure handling

- **A job fails:** fix forward. Delete the tag, correct the problem, tag again.
  Do not hand-upload an asset the workflow was supposed to build, because then
  nothing reproduces it.
- **A release is broken after publishing:** publish a corrected version rather
  than editing the assets in place. Someone has already downloaded the old one,
  and `rollback` exists for the people who have it.
- **An asset name is wrong:** treat it as breaking the updater, because it is.

## Expected output

A tag, a complete set of assets under their expected names, release notes, and
confirmation that a published artifact was actually downloaded and run.

## Security considerations

- Signing keys live in repository secrets and never in the tree. Check
  `.gitignore` still covers keystores and `key.properties`.
- The workflow removes signing material after the build. Do not add a step that
  prints it, and remember that anything echoed into a log is public for a
  public repository.
- Release workflow permissions stay at the minimum needed to publish.
- Publish checksums, because `localdrive update` verifies against them.
