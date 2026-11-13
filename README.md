# Island

A macOS 14+ menu bar app with an animated black overlay around the camera notch.

## Core shell (step 1)

- A transparent, nonactivating panel above the menu bar.
- Notch geometry from public AppKit screen APIs, with a pill fallback.
- Collapsed, compact, and expanded presentation states.
- Spring animation, hover, and click interaction.
- A modular interface for future features.
- Menu bar controls and shell settings.

Feature modules will follow after the core shell has been tested on hardware.
The primary hardware test is a MacBook Air 15-inch M3 with a notch on macOS 27.
The pill layout remains available for displays without a notch.

## Project structure

The app is built as a Swift package and assembled into `Island.app`.
See [Docs/Architecture.md](Docs/Architecture.md) for the core structure and the
confirmed `IslandModule` protocol.

## Build and run

Requires macOS 14+ and a Swift 6 toolchain (Xcode or Command Line Tools).
No external packages are used.

```sh
./Scripts/build-app.sh         # Debug bundle: build/Island.app
./Scripts/build-app.sh release # Optimized bundle at the same path
./Scripts/run.sh               # Build and launch through Launch Services
```

The bundle has `LSUIElement=true` and an ad-hoc signature. It runs as a menu bar
app without a Dock icon. Quit Island before rebuilding a running copy.

## Interaction

- Hover over the notch (including the thin black edge below it) for 0.25 seconds
  to expand. Leaving collapses it after 0.3 seconds.
- Click the black surface or **Pin** to keep it expanded. Click again, **Unpin**,
  or anywhere outside to collapse it.
- The capsule icon in the menu bar provides visibility, compact preview,
  Settings, and Quit. Settings persist visibility, display selection, and hover
  delay. Launch at login changes only when its toggle is used.
- Automatic display selection prefers a notched screen; a disconnected selected
  display temporarily falls back to automatic selection.

The expanded shell contains controls until real modules are added. Compact
preview demonstrates the two wings around the camera; it is temporary.

## Validation

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.cache/clang" \
swift test --disable-sandbox --disable-xctest \
  --cache-path .cache/swiftpm --config-path .swiftpm/configuration \
  --security-path .swiftpm/security
```

Tests use Swift Testing and cover screen coordinates, auxiliary-area fallback,
rounded hit regions, hover cancellation, pinning, preferences, and module
priority/lifecycle. The bundle script validates metadata and its signature.

Hardware checks after launch:

1. The collapsed shell hugs the physical notch; content stays below the camera.
2. Hover, leave, pin/unpin, and rapid direction changes animate smoothly.
3. Transparent panel areas and rounded corners let menu bar clicks through.
4. Interacting with the shell keeps the current app active; Settings opens a
   normal active window. There is no Dock icon.
5. Test another Space, a fullscreen app, wake, and external display changes.
6. Test Show Island, compact preview, and display selection from Settings.

Launch at login should be tested from a stable installed copy of `Island.app`
(for example in `/Applications`); this milestone does not install the app.

## Third-party attribution

Now Playing uses [MediaRemote Adapter](https://github.com/ungive/mediaremote-adapter)
by Jonas van den Berg, Alexander5015, and contributors, licensed under
[BSD-3-Clause](ThirdParty/MediaRemoteAdapter/LICENSE). Its source revision is
pinned in [UPSTREAM.md](ThirdParty/MediaRemoteAdapter/UPSTREAM.md).
The [ejbills Swift wrapper](https://github.com/ejbills/mediaremote-adapter) was
audited (also BSD-3-Clause); Island uses its own client rather than that wrapper.
Both licenses permit publishing this repository on GitHub with their notices
retained. See [Docs/NowPlaying.md](Docs/NowPlaying.md) for the source decision,
verification, and limitations.
