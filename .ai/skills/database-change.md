# Skill: changing the database schema

## Purpose

Change the schema without breaking an install that already holds someone's
files.

## When to use

Any new table, column, index or constraint, and any change to an existing one.

## Required context

- `server/migrations/`, which holds numbered SQL files.
- `server/internal/db/migrate.go`, which applies them in filename order on
  start.
- The tables the change touches, and every query that reads them.

## Pre-flight

Three questions, answered before writing SQL:

1. **Has anything shipped that already ran this migration?** If a version has
   been released, every migration in it has run on somebody's machine and will
   never run again.
2. **Can the new schema be produced without losing data?** A column being
   dropped or narrowed destroys whatever was in it. On SQLite, altering a
   column means rebuilding the table.
3. **Does the old code still work against the new schema?** During an update
   the binary is replaced and restarted, so there is a moment where either
   could be true.

## Workflow

1. **Add a new numbered file.** `0003_something_descriptive.sql`, following the
   existing numbering. Never edit `0001_init.sql` or any other migration that
   has shipped, however small the fix looks. The correct fix for a bad shipped
   migration is another migration.
2. **Write it to be safe to run twice.** `IF NOT EXISTS` where SQLite supports
   it. A migration that fails halfway leaves a database that still has to start.
3. **Prefer additive.** A new nullable column, or a new table, costs nothing to
   existing rows. Backfill in a separate statement rather than in the column
   definition.
4. **Update the models and queries** that read the affected tables.
5. **Test against a database that already has data**, not only an empty one.
   Create rows with the old shape, run the migration, assert the rows survived
   and mean the same thing.
6. **Check the backup path.** `localdrive backup` copies the database through
   SQLite's own online backup. If the change affects what a restore has to
   contain, say so in `docs/self-hosting/backups.mdx`.

## Validation

```
cd server && go test -race -count=1 ./...
```

Then a real run, because migrations apply on start and the failure mode is a
server that will not come up:

```
go run ./cmd/localdrive serve
```

Watch for the `migration applied` log line, stop it, and start it again to
confirm the second start is clean.

## Failure handling

- **The migration fails on start:** the server does not come up, which is the
  correct behaviour and also an outage on someone's machine. Never ship one
  that has not been run against realistic data.
- **You need to undo a shipped migration:** you cannot. Write a new one that
  moves forward into the state you want.
- **The change cannot be made without losing data:** stop and ask. That is a
  product decision, not an implementation detail.

## Expected output

- One new numbered migration, additive where possible.
- Model and query updates in the same change.
- A test that runs against pre-existing data.
- A summary that states explicitly whether this is backwards compatible, and
  what happens to an install that updates and then rolls back.

## Security considerations

- The database holds account records, session material and second factor
  secrets. A migration that copies a table copies those too. Do not leave a
  backup copy of a sensitive table behind after a rebuild.
- Never widen a permission by default. A new column controlling access defaults
  to the closed value, and existing rows are backfilled deliberately.
- Do not log row contents during a migration.
