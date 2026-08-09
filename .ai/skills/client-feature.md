# Skill: building or changing something in the client

## Purpose

Change the Flutter app without breaking a platform you did not test, a locale
you do not read, or the rule that the client is never the source of truth.

## When to use

Any change under `localdrive/`: a screen, a widget, a controller, a route.

## Required context

- `localdrive/AGENTS.md` for the local rules.
- The feature directory under `lib/features/`, which holds UI and controllers
  together.
- `docs/architecture/platform-integration.mdx` for what each platform can
  honestly do.

## Pre-flight

1. **Generate the code.** A clean checkout does not compile:

   ```
   flutter pub get
   dart run build_runner build --delete-conflicting-outputs
   ```

   An import that "does not exist" is this, not a missing file.

2. Check whether a widget in `lib/core/widgets/` already does this. The `Ld*`
   set exists so spacing, radius and motion stay consistent.
3. Decide which platforms the change affects. The same code runs on phones,
   desktops and the web.

## Workflow

1. **Server first, if the data is new.** The client displays what the server
   owns. If the information does not exist server side yet, that is a server
   change and this one waits.
2. Build the UI from the existing `Ld*` widgets and the theme. Do not hardcode
   a colour, a radius or a duration.
3. **Watch the state lifetime.** A provider that is `autoDispose` and also
   calls `ref.keepAlive()` outlives sign out and a server switch, and the next
   account sees the previous one's data. This has caused three separate bugs.
   Invalidate explicitly on sign out rather than trusting disposal.
4. **Handle the three states.** Loading, error with a way to retry, and empty
   are all real states a user reaches on first launch. An error with no retry
   is a dead end.
5. **Directional layout only.** `EdgeInsetsDirectional`, `start` and `end`.
   Never `left` and `right`. Arabic is a supported locale and the layout flips.
6. **Strings go in the `.arb` files**, both `app_en.arb` and `app_ar.arb`.
7. **`SafeArea` on mobile.** Desktop and web do not have the same insets and
   the same widget runs on all of them.
8. Write a widget test for the behaviour, in `test/`.

## Validation

```
cd localdrive && flutter analyze && flutter test
```

Both must be clean. The lint set is treated as errors, so a warning fails.

Then run it. Analysis does not catch a layout that overflows, a tap target
that is too small, or a screen that is unreadable right to left:

```
flutter run
```

Check the change on at least one mobile and one desktop target, and in both
text directions.

## Failure handling

- **Build fails on a missing generated file:** run `build_runner` again with
  `--delete-conflicting-outputs`.
- **`pumpAndSettle` times out:** something is animating forever. Pump a fixed
  duration instead of settling.
- **A `Semantics` label is not found in a test:** it is not laid out. Find by
  key or by rendered text.
- **A platform cannot do it:** say so in the UI rather than failing silently,
  and record it in `docs/architecture/platform-integration.mdx`.

## Expected output

- A change scoped to one feature directory, using the shared widgets and theme.
- Strings in both `.arb` files.
- A widget test covering the behaviour.
- A summary naming which platforms and which text directions you actually
  checked, and which you did not.

## Security considerations

- The client is not where permission is decided. Hiding a button is presentation
  and not enforcement. Anything that matters is refused by the server.
- Do not cache another account's data across a sign out. Invalidate on session
  change.
- Do not log tokens, passwords or file contents, including to the console in
  debug builds.
- Nothing may be written to the device that a signed out user could read back.
