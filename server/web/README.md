# The web client

This directory is what Caddy serves at `/` when running under Docker. It is
empty in the repository because the built web client is a build artifact, not
source.

To fill it:

```
cd localdrive
flutter build web --release
cp -r build/web/* ../server/web/
```

Then `docker compose up -d`, and the browser UI is available at the server's
address.

You do not need this to use Local Drive. The Android, Windows, Linux and macOS
apps talk to the same API and are the usual way in. The API itself is served by
the Go binary regardless of whether anything is in here.

Running the binary directly does not use this directory at all; the bare server
serves the API and nothing else.
