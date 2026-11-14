# Island

A Dynamic Island-inspired menu bar app for macOS, built with Swift and SwiftUI.
Island wraps the camera notch in a glass surface that expands on hover to show
playback controls and timers.

**Current version:** 0.3.0 · **Milestone tag:** `v0.3-multimodule`

## Features

- **Notch-aware shell:** collapsed, compact, and expanded states, fast hover
  expansion, spring transitions, and a pill fallback for displays without a notch.
- **Now Playing:** compact artwork and a playback indicator; expanded title,
  artist, artwork, progress, and previous/play-pause/next controls.
- **Multiple modules:** compact shows the highest-priority active module;
  expanded dots switch pages. Timer takes priority over playback.
- **Timer and Stopwatch:** start, pause, resume, reset, 1/5/10-minute presets,
  custom durations, and a completion animation with one system alert sound.
- **Shared design system:** system typography, dark glass, rounded artwork,
  cover-derived accents, reusable controls, and a masked marquee for long titles.
- **Accessibility and settings:** Reduce Motion, display selection, hover delay,
  overlay visibility, and an optional launch-at-login setting.

Island runs without a Dock icon. Overlay controls keep the current app active;
Settings and the Timer controller open as ordinary windows.

## Requirements

- macOS 14 or later, as declared by the package.
- Swift 6 and Apple's macOS SDK through Xcode or Command Line Tools.
- Local validation hardware: MacBook Air 15-inch M3 with a notch, macOS 27.2.1.
  Other macOS versions and hardware still need testing.

No external Swift packages are required. The pinned MediaRemote Adapter is built
from source using Apple's clang; CMake is not needed.

## Build and run

From the repository directory:

```sh
./Scripts/build-app.sh         # Debug: build/Island.app
./Scripts/build-app.sh release # Release: build/Island.app
open -g build/Island.app
```

Alternatively, `./Scripts/run.sh` builds and launches debug;
`./Scripts/run.sh release` builds and launches release.

Quit Island before rebuilding: both configurations replace the same generated
bundle. The scripts validate bundle metadata and apply an ad-hoc signature.
The app is intended for local builds and is not notarized. Build products,
local captures, logs, and caches are excluded from Git.

For launch at login, use a stable installed copy, such as
`/Applications/Island.app`, and enable the setting explicitly. The build script
does not install the app or change login items.

## Using Island

1. Play media or open **Timer & Stopwatch…** from Island's menu bar icon and
   start a timer. With no active modules, Island stays collapsed.
2. Hover over the notch or its thin lower edge. Default expansion delay:
   0.05 seconds. Leaving collapses it after 0.3 seconds.
3. With both playback and Timer active, compact shows Timer. Use the expanded
   dots to select either page. Fresh hover starts with the priority winner.
4. Use the left expanded-wing clock to open Timer, or the right gear for
   Settings. Paused tracks and timers remain active.
5. A completed timer stays visible until **Done/Reset**. **Restart** starts the
   same duration again. Reset before switching Timer/Stopwatch modes.

Custom timers support 1 second through 24 hours. Sleep counts toward elapsed
time; completion is delivered when the app resumes. Sessions are not restored
after quitting Island.

The menu bar also offers visibility, Settings, Quit, and **Preview Compact
Layout**, a diagnostic option without an active module. A disconnected selected
display temporarily falls back to automatic selection.

## Now Playing sources and permissions

The default source is a pinned
[MediaRemote Adapter](https://github.com/ungive/mediaremote-adapter) in an isolated
helper process. It uses private MediaRemote APIs to read the system-selected
player, including supported browser sessions. Island itself does not load the
private framework. A detected helper failure disables that source and starts
the configured Music/Spotify backup.

The backup uses Apple Events and checks only enabled players that are already
running. Island explains Automation permission and requests it only after
**Allow Music Control…** or **Allow Spotify Control…** is clicked. Normal idle
playback does not trigger a fallback or a prompt.

Use **Use Music/Spotify backup** in Settings if Automatic stops reporting a
playing session. **Retry Automatic** explicitly retries the helper. Denied
permission can be changed in System Settings → Privacy & Security → Automation.
A different build signature or installation may require consent again.

Playback metadata is read locally. Spotify backup artwork may be downloaded
over HTTPS. See [Docs/NowPlaying.md](Docs/NowPlaying.md) for source behavior,
permission handling, the licensing audit, and a playback checklist.

## Validation

```sh
./Scripts/test.sh
./Scripts/test.sh release
```

Version 0.3.0 passes **48 Swift Testing tests in both debug and release**.
Coverage includes notch geometry, hit regions, hover cancellation, module
priority and paging, playback decoding and progress, source fallback, explicit
consent, helper cancellation, and timer/stopwatch timing and completion.

Native captures were reviewed for compact Timer, both expanded pages, pause,
Stopwatch, completion, idle collapse, and Reduce Motion. The shared Timer view
was also checked with real UI actions for presets, custom durations, controls,
and completion.

The test script locates Swift Testing resources in the installed toolchain.
If the default build planner fails, try:

```sh
ISLAND_TEST_BUILD_SYSTEM=native ./Scripts/test.sh
```

Manual checks still include Spotify and browser transport controls, the final
app's Automation prompt, audible alert volume, physical sleep/wake, fullscreen,
Spaces, external displays, and launch at login.

## Project structure

```text
Sources/IslandApp/       App lifecycle, menu bar, windows, and shell views
Sources/IslandCore/      Geometry, panel, modules, design, playback, and timers
Tests/IslandCoreTests/   Swift Testing suite
Resources/              Bundle metadata and helper watchdog
ThirdParty/             Pinned adapter source and license notices
Scripts/                Build, bundle, sign, launch, and test
Docs/                   Architecture, design, and playback notes
```

Modules implement the confirmed `IslandModule` contract. The registry handles
enabled lifecycle, idle/active state, priority, and independent expanded
selection. Timer uses a continuous clock rather than wall time. See
[Docs/Architecture.md](Docs/Architecture.md) and
[Docs/Design.md](Docs/Design.md) for implementation details and checklists.

## Development milestones

| Milestone | Changes |
| --- | --- |
| Core shell | Swift package to Island.app, signing, notch geometry, hover, spring transitions, menu bar, and settings. |
| Now Playing | Isolated helper, Music/Spotify backups, explicit Automation consent, artwork, progress, and controls. |
| Design foundation | Shared tokens and components, glass, artwork accents, marquee, notch-edge hover fix, and faster expansion. |
| 0.3.0 | Active-module priority and paging, Timer/Stopwatch, completion alerts, and 48 tests per configuration. |

## Known limitations

- Private MediaRemote APIs can change after macOS updates. Music/Spotify backups
  do not cover browsers. The current automatic source is unsuitable for Mac App
  Store submission.
- macOS elects one Now Playing player. Metadata and artwork may arrive late;
  commands depend on player support and the available playback queue.
- Missing artwork, unknown duration, and no track are normal states. The compact
  playback indicator reflects state; it is not an audio visualizer.
- Timer sessions do not survive app exit. Alerts are delivered after suspension
  ends, rather than while the Mac or app is asleep.

## Licensing and attribution

Island's original code is licensed under [BSD-3-Clause](LICENSE), copyright
2026 Island contributors. Third-party code retains its own license notices.

[MediaRemote Adapter](https://github.com/ungive/mediaremote-adapter) is by Jonas
van den Berg, Alexander5015, and contributors, licensed under
[BSD-3-Clause](ThirdParty/MediaRemoteAdapter/LICENSE). The source revision is
pinned in [UPSTREAM.md](ThirdParty/MediaRemoteAdapter/UPSTREAM.md). Binary builds
include both the Island and adapter license notices.

The [ejbills Swift wrapper](https://github.com/ejbills/mediaremote-adapter) was
audited under BSD-3-Clause; Island uses its own Swift client instead of the
wrapper. The [audited license](ThirdParty/Licenses/MediaRemoteAdapter-Swift-BSD-3-Clause.txt)
is retained for reference. Both third-party licenses permit GitHub publication
when their notices and terms are preserved.
