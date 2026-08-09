# Logo assets

`mark.svg` is the master. The app itself never loads it: `LdLogo` draws the
same geometry in code so each layer can animate independently during
onboarding, which an SVG cannot do without shipping four separate files.

This file is the source for the raster exports that the platform toolchains
need and that cannot be drawn at runtime:

- `mark_1024.png`, the app icon source for `flutter_launcher_icons`
- `mark_foreground_1024.png`, the Android adaptive icon foreground layer
- `mark_splash.png`, the splash image for `flutter_native_splash`

Regenerate them from `mark.svg` on a background of `#141414`, then run:

    dart run flutter_launcher_icons
    dart run flutter_native_splash:create
