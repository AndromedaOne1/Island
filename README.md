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
