# The iOS Share Extension

Appearing in the iOS share sheet needs a real second target. Unlike Android,
there is no manifest entry that does it, and a target cannot be created from a
text file, so this folder holds the finished source and the one step that has
to happen in Xcode.

Everything here is complete. The only thing missing is the target itself.

## Adding the target

1. Open `ios/Runner.xcworkspace` in Xcode.
2. **File, New, Target**, choose **Share Extension**, name it `ShareExtension`.
   When Xcode offers to create a scheme, decline it; the Runner scheme builds
   the extension as a dependency.
3. Delete the `ShareViewController.swift`, `Info.plist`, `MainInterface.storyboard`
   and entitlements file Xcode generated inside the new group.
4. Drag `ShareViewController.swift`, `Info.plist` and `ShareExtension.entitlements`
   from this folder into the `ShareExtension` group, with **Copy items if
   needed** unticked so they stay tracked in this repository.
5. In the target's **Build Settings**, set **Info.plist File** to
   `ShareExtension/Info.plist` and **Code Signing Entitlements** to
   `ShareExtension/ShareExtension.entitlements`.
6. In **Signing & Capabilities** for *both* the `Runner` target and the
   `ShareExtension` target, add **App Groups** and tick `group.app.localdrive`.

## Why the app group matters

An extension runs in its own process with its own container. It cannot hand a
file to the app directly. The extension copies what it was given into the
shared group container, writes `pending-share.json` naming what it copied, and
opens the app through the `localdrive://share` scheme. The app reads that
manifest on launch and enqueues real uploads from it.

That indirection is what makes a share arriving while the app is closed work at
all. Without the group, both halves are correct and nothing is ever delivered.

## If you ship under your own account

Change `group.app.localdrive` in three places, and keep them identical:

- `ios/Runner/Runner.entitlements`
- `ios/ShareExtension/ShareExtension.entitlements`
- the `appGroup` constant at the top of `ShareViewController.swift`
