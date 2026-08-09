# Skill: adding or changing an HTTP endpoint

## Purpose

Add or change part of the API without breaking the clients that depend on it or
putting a security decision in the wrong layer.

## When to use

Anything that changes the HTTP surface: a new route, a new field, a new status
code, a new error, or a change to an existing one.

## Required context

- `server/AGENTS.md` for the layer rules.
- `server/internal/httpapi/respond.go`, which is the one error envelope.
- `docs/api-reference/` for the documented contract.
- Whether `localdrive/` calls this endpoint. It usually does.

## Pre-flight

1. Search for an existing endpoint that already does most of this. Extending
   one is nearly always better than adding a near duplicate.
2. Decide whether this is additive. Adding a field is safe. Renaming or
   removing one is a breaking change to a public contract and needs saying out
   loud.
3. Identify the capability being exercised, and confirm the domain package can
   already express it.

## Workflow

1. **Domain first.** Put the rule in `internal/files`, `auth`, `shares`,
   `libraries` or `settings`. That includes the permission decision:
   `files.Require` returns `ErrForbidden`, and that is where the answer belongs.
   A handler that inspects a role and decides for itself has hidden a security
   decision.
2. **Return a sentinel error** for each failure mode, wrapped with `%w` so
   `errors.Is` works through the layers.
3. **Add the case to `fail`** in `internal/httpapi/respond.go` if the error is
   new. Without a case it becomes a 500, which is the most common way a new
   error is shipped wrong.
4. **Write the handler**: decode, call the service, `a.fail(w, r, err)` on
   error, `writeJSON` on success. No status codes or messages invented inline.
5. **Register the route** in the same style as its neighbours, under the same
   middleware. Check the authentication middleware actually covers it. A route
   registered on the wrong router is an unauthenticated endpoint.
6. **Test it** in `internal/app`, which drives the real HTTP surface through the
   harness. Cover the success path and the forbidden path. **A permission test
   is not optional:** assert that another account gets 403, not just that the
   owner gets 200.
7. **Document it** in `docs/api-reference/`.
8. **Update the client** if `localdrive/` needs to use it, or note explicitly
   that it does not yet.

## Validation

```
cd server && gofmt -l . && go vet ./... && go test -race -count=1 ./...
cd landing && npm run build
```

Exercise the endpoint for real as well, against `go run ./cmd/localdrive serve`,
including one request that should be refused.

## Failure handling

- **The test returns 500 instead of the status you expected:** the error has no
  case in `fail`. That is the cause almost every time.
- **The permission test passes when it should not:** check the route is under
  the authenticating middleware, and that the service is being given the
  caller's id rather than the object's owner id.
- **You need a response shape that does not fit the envelope:** do not add a
  second envelope. Ask.

## Expected output

- Rule in the domain package, thin handler, one error envelope.
- Tests for both the allowed and the refused path.
- `docs/api-reference/` updated in the same change.
- A summary that says plainly whether any existing response shape changed.

## Security considerations

- Authorisation is checked on the server for every request, per object. Never
  trust an id in the body to mean the caller owns it.
- Admin is not a master key. An endpoint that lets an administrator read
  another account's file contents changes the meaning of the product and is not
  an implementation detail.
- Cap request bodies. `maxJSONBody` exists for this.
- Never put a token, a password or a session id in a log line or an error
  message that reaches the client.
- If the endpoint takes a filename or a path fragment, it goes through
  `pkg/pathsafe`. No exceptions.
