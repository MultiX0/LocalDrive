# Local Drive, the app

The Flutter client for [Local Drive](../README.md). One codebase producing the
phone, tablet, desktop, and web builds.

The app is a window into whichever server it has been pointed at. Every
business rule, quota, permission, versioning, sharing, lives on the server, so
this side never has to decide any of them, and a future client would get
correct behaviour for free.

## Running it

```
flutter pub get
flutter gen-l10n
flutter run              # or -d chrome, -d windows, -d macos, -d linux
```

You need a server to point it at. See
[Quick start](../docs/getting-started/quick-start.mdx).

## Checks

```
flutter analyze          # must be clean, not merely free of errors
flutter test
```

Building each target, as a smoke test that the platform folders are still
coherent:

```
flutter build web --release
flutter build windows --release      # or macos, linux, apk
```

## Layout

The full rules are in [`structure.md`](../structure.md) at the repository root.
In short:

```
lib/
  main.dart        bindings, url strategy, the global error surface
  app.dart         MaterialApp.router, theme, locale
  imports.dart     the barrel every feature file imports
  core/
    constants/     breakpoints, colors, radii, motion, typography, endpoints
    enums/         file_category, transfer_status
    theme/         the one ThemeData, composed per locale
    router/        routes and the redirect
    services/      api_client, websocket, secure storage, device info
    utils/         formatters
    widgets/       the Ld* component kit
  features/
    <feature>/{db,models,controller,providers,pages,widgets}
  l10n/            app_en.arb, app_ar.arb, glossary.md
```

Two feature folders are worth knowing about before adding to them:

- `features/gallery` is a flat photo timeline, not a folder listing with a
  filter. It lays out from the server's recorded pixel dimensions, which is
  what lets the masonry settle before any thumbnail arrives.
- `features/preview/db/document_parser.dart` reads xlsx, docx, ods, odt, rtf
  and csv. They are all a zip of XML, so one set of machinery covers them and
  the rendering stays ours.

`core/db/local_db.dart` is the one Drift database: the metadata cache, the
offline registry, and the durable transfer queue. After changing a table:

```
dart run build_runner build --delete-conflicting-outputs
```

The dependency direction is one way and never skips:

```
Page -> Provider / Controller -> Db -> ApiClient | WebSocketService
```

## The design system

Everything visible is the app's own. Nothing falls back to a stock Material
component, including the states that usually leak: loading, refreshing, and
the very first frame.

| Instead of | This app uses |
| --- | --- |
| `AlertDialog`, `showDialog` | `LdBottomSheet` |
| `SnackBar` | `LdToast` |
| `CircularProgressIndicator` | `LdSpinner`, a dot ring |
| `RefreshIndicator` | `LdRefresh`, whose pull fills the same ring |
| `Switch`, `Checkbox`, `Radio` | `LdSwitch`, `LdCheckbox`, `LdRadioRow` |
| Material icons | `LdIcon`, a drawn line set |
| A spinner while a list loads | `LdListSkeleton`, `LdGridSkeleton` |
| An empty list rendering nothing | `LdEmptyState` |
| `Text('Error: $e')` | `LdErrorState`, retry bound to the failed call |
| Flutter's default web loader | a branded boot screen in `web/index.html` |
| `NetworkImage` | `LdRemoteImage`, disk cached, shimmer, fades in |
| `DataTable` | the spreadsheet reader's own grid |
| A markdown package's renderer | `MarkdownView`, this app's own widgets |

Typography is a function of the locale rather than a static class: Space
Grotesk for Latin, IBM Plex Sans Arabic for Arabic, resolved once at the
`ThemeData` level so every widget reading `Theme.of(context).textTheme` gets
the right face. No widget hardcodes a font.

## Responsive

`LdResponsive` is the single breakpoint decision point: mobile below 600,
tablet 600 to 1024, desktop above 1024. A `*_page.dart` holds only that choice;
the layouts live in `pages/mobile`, `pages/tablet`, and `pages/desktop`.

Desktop is a different design, not the phone stretched:

| | Mobile | Desktop |
| --- | --- | --- |
| Navigation | floating pill bar | persistent sidebar with a quota footer |
| Chrome | stacked header, then a toolbar | one slim top bar, everything inline |
| Search | its own screen | a field in the top bar |
| Selecting a file | pushes a preview screen | opens a details pane beside the list |
| Settings | push a section, pop back | master and detail, both visible |
| Drag and drop | not applicable | a visible drop zone over the listing |

## The native side

Four platform folders carry real code, not just configuration.

| Platform | What is native, and why |
| --- | --- |
| Android | `TransferService`, a foreground service, so a transfer survives the app leaving the screen. `TransferRetryWorker` wakes the app when the network returns. |
| iOS | A Share Extension in `ios/ShareExtension/`. It needs one step in Xcode that a text file cannot do; see the README there. |
| Desktop | `bitsdojo_window` for the app's own title bar, `tray_manager` so closing the window does not kill a running transfer. |
| Web | A branded boot screen and a PWA manifest with a share target. |

All of it goes through one method channel, `app.localdrive/platform`. Anything
that could be done in Dart is done in Dart.

Details, including what each platform can honestly promise:
[Platform integration](../docs/architecture/platform-integration.mdx).

## The logo

`LdLogo` draws the mark in code so each layer can animate independently through
onboarding: closed folder, then the sheet rises, then the sync arc draws, then
the node fills.

`assets/logo/mark.svg` holds the same geometry and is the source for the raster
exports the platform toolchains need. After changing either, regenerate:

```
dart run tool/generate_logo_assets.dart
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Localization

Every user facing string lives in both `lib/l10n/app_en.arb` and
`app_ar.arb`. Check new strings against `lib/l10n/glossary.md` first, so tone
stays consistent. Never inline a literal.

```
flutter gen-l10n
```

See [Localization](../docs/localization.mdx).

## House rules

Shared logic in one place. No business logic in a `build` method. No page or
widget importing `dio`, `drift`, or `web_socket_channel`.

Full list: [Code style](../docs/contributing/code-style.mdx).
