# Island

A macOS 14+ menu bar app with an animated black overlay around the camera notch.

## First milestone

- A transparent, nonactivating panel above the menu bar.
- Notch geometry from public AppKit screen APIs, with a pill fallback.
- Collapsed, compact, and expanded presentation states.
- Spring animation, hover, and click interaction.
- A modular interface for future features.
- Menu bar controls and shell settings.

Feature modules will follow after the core shell has been tested on hardware.

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
