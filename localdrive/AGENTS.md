# Notes for coding agents: the client

Local rules for `localdrive/`. The root [`AGENTS.md`](../AGENTS.md) covers
everything general and is not repeated here.

One Flutter codebase for Android, Windows, Linux, macOS, iOS and the web. It is
an interface to the server. It may cache anything for speed and may never be
the only place something is true.

## Generated code is not in the repository

`*.g.dart` and `*.freezed.dart` are gitignored, and so is the generated
localisation output. A clean checkout does not compile until you generate them:

```
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

Run this first. An import that "does not exist" is almost always this and not a
missing file. Never commit a generated file, and never hand edit one.

## Layout

- `lib/core/` is shared: `theme`, `router`, `services`, `db`, `widgets`,
  `constants`, `enums`, `utils`.
- `lib/features/<feature>/` holds one feature, with its UI and its controllers
  together. Cross feature code moves to `lib/core/`, it does not get imported
  sideways between features.

## State

Riverpod. Controllers live beside the feature they serve.

The trap that has already caused three bugs: a provider marked `autoDispose`
that also calls `ref.keepAlive()` survives sign out and a server switch, so the
next account sees the last one's data. When state must not outlive a session,
invalidate it explicitly on sign out rather than relying on disposal. There is a
`refreshServerData` helper for exactly this.

## Routing

`go_router`, with routes declared in `lib/core/router/`. Deep links and share
links resolve through the same table, so a new route needs checking on the web
and on mobile, not only where you added it.

## Talking to the server

`lib/core/services/api_client.dart` owns the HTTP client and the base URL.

The scheme for an address someone types is guessed there: an IP address or a
name ending `.local`, `.lan`, `.home` or `.internal` gets `http`, and anything
that looks like a public domain gets `https`. This matches what the server
actually serves and is documented in
`docs/getting-started/ports-and-addresses.mdx`. Changing one without the other
breaks connecting.

Not everything goes through Dio. `cached_network_image` fetches thumbnails on
its own, and the WebSocket is a separate transport. A change to authentication
or base URL handling has to account for all three.

## Design system

Non-negotiable, and enforced by review rather than by a linter:

- **No shadows and no gradients.** Flat fills with a 1px border.
- **Two accent colours only**, `#4C8DFF` and `#EE7759`. The file type colours
  are semantic and must not be used decoratively.
- Use the `Ld*` widgets in `lib/core/widgets/` rather than raw Material
  widgets, so spacing, radius and motion stay consistent.
- Do not hardcode a colour or a radius. They are in `lib/core/theme/` and
  `lib/core/constants/`.

## Platforms, localisation and accessibility

- Arabic is a supported locale and the layout is right to left in it. Use
  directional insets (`EdgeInsetsDirectional`, `start`/`end`), never `left` and
  `right`. Test a layout change in both directions.
- User facing strings come from the `.arb` files in `lib/l10n/`. Adding a string
  means adding it to `app_en.arb` and `app_ar.arb`.
- Mobile needs `SafeArea`. Desktop and web do not have the same insets, and the
  same widget runs on all of them.
- Touch targets have a minimum size and there is a test that enforces it.
- A feature that a platform genuinely cannot support should say so in the UI
  rather than failing quietly. See `docs/architecture/platform-integration.mdx`
  for what each platform can honestly promise.

## Before you finish

```
flutter analyze
flutter test
```

Both must be clean. `flutter analyze` treats the project's lint set as errors,
so a warning is a failure.

Widget tests live in `test/`. When you fix a UI bug, the regression test is
usually a widget test that pumps the widget and asserts on what is rendered.

Testing gotchas that have cost real time: pump and settle does not finish while
an infinite animation runs, and a `Semantics` label is not found unless the
widget is actually laid out. Prefer finding by key or by rendered text.
