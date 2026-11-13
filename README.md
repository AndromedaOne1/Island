# Island

A macOS 14+ menu bar app with an animated black overlay around the camera notch.

## Core shell (step 1)

- A transparent, nonactivating panel above the menu bar.
- Notch geometry from public AppKit screen APIs, with a pill fallback.
- Collapsed, compact, and expanded presentation states.
- Spring animation, hover, and click interaction.
- A modular interface for future features.
- Menu bar controls and shell settings.

The core shell is accepted. Now Playing (step 2) is implemented.
The primary hardware is a MacBook Air 15-inch M3 with a notch on macOS 27.2.1.
The pill layout remains available for displays without a notch.

## Now Playing (step 2)

- Compact artwork and an animated playback indicator on opposite notch wings.
- Expanded artwork, title, artist, interpolated progress, and previous/play-pause/next.
- A pinned MediaRemote Adapter running in an isolated helper process.
- Music and Spotify backups through Apple Events when the automatic source fails
  or **Use Music/Spotify backup** is selected in Settings.
- Explicit, player-specific Automation consent with an explanation before asking.

No current track is a normal collapsed state. Paused tracks remain visible with
static indicators. Missing artwork and unknown duration are supported.

## Project structure

The app is built as a Swift package and assembled into `Island.app`.
See [Docs/Architecture.md](Docs/Architecture.md) for the core structure and the
confirmed `IslandModule` protocol.

## Build and run

Requires macOS 14+ and a Swift 6 toolchain (Xcode or Command Line Tools).
No external Swift packages are used. The vendored adapter is built from source
with Apple's clang; CMake and additional installations are not required.

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

When a track is available, Now Playing owns the compact and expanded content.
Compact preview remains a shell diagnostic when no module is active.
Now Playing Settings can disable the module, select the backup, enable individual
backup players, or retry the automatic source. The backup checks only running
players and never prompts for Automation on its own: click **Allow Music Control…**
or **Allow Spotify Control…** when shown. Denied access can be changed in
System Settings → Privacy & Security → Automation.

## Validation

```sh
./Scripts/test.sh
./Scripts/test.sh release
```

Tests use Swift Testing and cover screen coordinates, auxiliary-area fallback,
rounded hit regions, hover cancellation, pinning, preferences, and module
priority/lifecycle, Now Playing data parsing, progress, source fallback, explicit
consent, and process timeout/cancellation. The test script locates Swift Testing
frameworks and macros in the installed toolchain, including Command Line Tools.
If the Swift build planner fails, `ISLAND_TEST_BUILD_SYSTEM=native ./Scripts/test.sh`
selects its alternative backend. The bundle script validates metadata and signatures.

See [Docs/NowPlaying.md](Docs/NowPlaying.md) for local playback verification and
the Music/Spotify/browser manual checklist.

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
