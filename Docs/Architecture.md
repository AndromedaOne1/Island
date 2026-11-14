# Island architecture

Status: Swift package to `Island.app` and the `IslandModule` contract confirmed.
Core shell, Now Playing, and the design foundation are accepted. Version 0.3.0
adds active-module paging and Timer/Stopwatch; milestone tag: `v0.3-multimodule`.

## Targets and directories

```text
Package.swift
Sources/
  IslandCore/
    Geometry/          Screen selection and notch layout
    Presentation/      Three-state model and animated shape
    Panel/             Nonactivating NSPanel and pointer tracking
    Modules/           IslandModule protocol and priority registry
    Settings/          Persistent shell preferences
    Design/            Shared visual tokens, components, and artwork palette
    NowPlaying/        Playback model, source coordination, processes, and views
    Timer/             Continuous-clock timer/stopwatch model, lifecycle, and views
  IslandApp/
    App/               App delegate, menu bar item, and settings window
    Views/             Shell content and settings interface
Tests/
  IslandCoreTests/     Geometry, interaction, module selection, playback, and timers
Resources/
  Info.plist           App bundle metadata; macOS 14 minimum
  MediaRemote/         Island-owned helper parent-lifetime watchdog
ThirdParty/            Pinned adapter sources and retained license notices
Scripts/
  build-app.sh         Build, bundle, and ad-hoc sign Island.app
  build-mediaremote.sh Build the isolated adapter framework from source
  run.sh               Build and launch the app bundle
  test.sh              Run Swift Testing with installed toolchain resources
```

Two local targets keep AppKit integration and the presentation model available
to tests without introducing external dependencies or multiple feature packages.

## Module boundary

```swift
import Combine
import SwiftUI

public enum CompactPosition {
    case leading
    case trailing
}

@MainActor
public protocol IslandModule: ObservableObject
    where ObjectWillChangePublisher == ObservableObjectPublisher {
    var id: String { get }
    var title: String { get }
    var priority: Int { get }
    var isActive: Bool { get }

    func compactView(for position: CompactPosition) -> AnyView
    func expandedView() -> AnyView
    func start()
    func stop()
}
```

The registry owns module instances, manages their enabled lifecycle, and forwards
observable updates to the shell. `isActive` is the authoritative module state;
the `state` convenience property maps it to `IslandModuleState.idle`/`.active`.
The highest-priority enabled active module always owns compact. Equal priorities
use stable identifier order. `activeModules` exposes that same ordered list.
Expanded uses `expandedModule`, independently selected with `select(_:)` or
`cycle(by:)`. Invalid/idle/disabled selections are rejected. A selected module
becoming idle or disabled falls back to the priority winner; a new higher-priority
module does not interrupt a manually selected page. Each fresh hover expansion
clears the page selection and starts with the compact winner.
Only the module boundary erases view types; each module can use concrete SwiftUI
views internally. Compact views occupy separate wings outside the notch.

Two or more active modules add a 24-point row of clickable dots below the content.
Dots expose module names, selected accessibility traits, and previous/next
accessibility actions. Page changes use the shared fade/scale/blur transition;
Reduce Motion uses opacity only. The shared 162-point content viewport keeps the
dots stationary between pages. Expanded height grows by 24 points only when
paging is needed; the existing panel canvas has room for that row.

The app registers `NowPlayingModule` at priority 100. A playback snapshot or a
pending backup consent notice activates it. Paused media remains active. Timer
is registered at priority 200. Without any active modules, ordinary hover keeps
the shell collapsed; activation under an already-hovered pointer can expand it.
Explicit compact preview remains a shell diagnostic exception.

## Timer and Stopwatch

`TimerModel` separates timing from scheduling and UI. Its phases are idle,
running, paused, and finished, with countdown/stopwatch modes. Running and paused
sessions are active; a completed countdown stays active until Done/Reset. Mode
and duration changes require idle. Presets are 1, 5, and 10 minutes; custom
minute/second controls support 1 second through 24 hours without keyboard focus
inside the nonactivating panel. Start also applies an open custom editor.

The injected clock defaults to Swift `ContinuousClock`, counting sleep while
avoiding wall-clock adjustments. Pause stores elapsed time and resume starts a
new anchor. Countdown clamps at zero; stopwatch accumulates elapsed time. A
single cancellable 100 ms task runs only while an enabled session is running.
Completion cancels ticking, invokes one system alert sound, and shows a brief
1.2-second celebration. Reduce Motion suppresses scale and progress interpolation.
Stopping the module cancels tasks, freezes running time, and suppresses alerts.
Timer state is in memory and is not restored after quitting Island.

The Timer & Stopwatch menu item and left expanded-wing clock button open a small
controller window using the same module view. This provides a way to configure
an idle module without publishing it as active. Once started, the timer appears
in compact and in the expanded active-page list. The window is intentionally
activating; ordinary overlay playback and timer controls remain nonactivating.

## Now Playing boundary

`NowPlayingSource` delivers Sendable playback values and source events to the
main actor. `NowPlayingCoordinator` owns source selection, permissions, commands,
and generation guards. An automatic source failure clears stale media and starts
the configured backup; idle data does not cause failover.

`MediaRemoteSource` launches a bundled Perl adapter as a separate process; Island
never loads the private framework itself. A bounded stream preserves output
ordering, and a serial background actor frames JSON and decodes artwork bytes.
Process I/O, deadlines, termination, and descriptor cleanup run on a dedicated
queue. Playback command helpers are short-lived and cancellable.

`AppleEventsSource` checks only running enabled Music/Spotify processes. It queries
permission without a prompt; an explicit Allow action requests consent. Scripts
and descriptors stay on a serial background actor. Network artwork and ImageIO
thumbnail decoding stay off the main actor and reject oversized images.

`PlaybackSnapshot` extrapolates position from the source position, timestamp, and
playback rate; pause freezes it and unknown duration has no invented percentage.
Source callbacks, command results, and artwork deliveries are guarded against
stale lifetimes and tracks. See [NowPlaying.md](NowPlaying.md) for the pinned
revision, verified behavior, licensing, and failure limitations.

## Panel and interaction

- One overlay is shown on the automatically selected notched screen, falling back
  to the main screen. A screen preference allows selecting any connected display.
- Read safe-area and auxiliary top-area geometry through public `NSScreen` APIs.
  Recalculate on display changes, wake, and active Space changes.
- Use a borderless `NSPanel` with `nonactivatingPanel`, a transparent background,
  no shadow, no key/main-window eligibility, and a level above the menu bar.
- Join all Spaces with `canJoinAllSpaces`, `fullScreenAuxiliary`, and `stationary`.
- Keep a stable panel canvas for SwiftUI's spring animation. Transparent areas
  pass through mouse input by switching `ignoresMouseEvents` with pointer tracking.
- A local/global mouse monitor observes pointer motion without keyboard monitoring
  or Accessibility access. A tracking area handles entry and exit over the panel.
- Hover expands an active island after a configurable delay. With no active
  modules it stays collapsed. Leaving collapses after a short delay.
  Surface clicks never change expansion; playback controls retain their actions.
- A custom `Shape` animates its top and bottom corner radii alongside its size.
- Opening Settings is an explicit user action and activates the settings window.
  Showing and interacting with the overlay never activates the application.

`ScreenGeometry` snapshots AppKit data into values for geometry tests.
`IslandLayout` anchors the visible surface at the screen's top edge, independent
of `visibleFrame` and the menu bar's autohide state. Valid auxiliary areas define
the notch gap; when a notched screen temporarily lacks valid areas, a centered
200-point estimate protects the camera strip. Only screens with no top safe-area
inset use the detached pill, eight points below the top edge.
The notched window extends one point above the screen to avoid a translucent
compositor edge. Content is inset by that same point, and input uses the exact
overscanned bounds and shape path. Including overscan in the input bounding box
keeps the physical screen's top edge inside hover detection; `CGRect.contains`
otherwise excludes that maximum edge. Design geometry and motion live in
`IslandDesign`;
see [Design.md](Design.md) for the shared components and visual verification.

`IslandInteraction` cancels pending hover and collapse tasks on dismiss/reset.
Hover exclusively owns expansion; opening Settings dismisses the overlay until
the pointer leaves and reenters.
`AnimatedSurface` reports interpolated dimensions and radii to the panel
controller so pointer routing follows the animation. A 30 Hz pointer-position
check complements mouse monitors during menu tracking; it stops when hidden.
Hosting safe-area adjustments and automatic window frame constraining are
disabled because the panel deliberately occupies the notch strip.

The app delegate retains the panel, status item, and settings window. Overlay
input uses a panel that cannot become key/main; only opening Settings explicitly
activates the app. Shutdown cancels transitions, removes observers and monitors,
invalidates pointer tracking, and stops enabled modules.

## Settings and scope

Store overlay visibility, display selection, and hover delay in `UserDefaults`.
Persist Now Playing enablement, source preference, and individual backup toggles.
Expose module enablement through the registry. Launch at login
uses public `SMAppService.mainApp` and changes only when its toggle is used.

No private APIs are needed for the core shell. The accepted Now Playing source
decision uses private MediaRemote inside its helper and public Apple Events as
the Music/Spotify backup.
Calendar, Battery, HUD, shelf, and device-use features remain later milestones.

## Validation

Build the app bundle with the installed Swift toolchain. Test notch/fallback
geometry on offset and negative-coordinate screens, invalid auxiliary geometry,
module priority, independent paging, lifecycle, countdown/stopwatch timing,
single completion alerts, and hover state transitions. Launch the
bundle and check panel flags, active application, and screen placement. Manual
hardware testing must cover the physical notch, menu interaction, fullscreen,
Spaces, external monitor changes, animation, and launch-at-login behavior.

For version 0.3.0, 48 Swift Testing tests pass in debug and release. Native
screen captures verify compact Timer priority, both expanded pages, paused Timer,
Stopwatch, completion, and idle collapse with ordinary and reduced motion.
The same Timer view in a normal test window was checked through real UI actions:
all presets, zero-duration rejection, a three-second custom countdown, Done,
pause/resume/reset, and Stopwatch. Sleep is covered by an injected-clock jump;
physical sleep/wake and audible alert volume still need hardware testing.

Manual milestone checklist:

1. Start playback and a timer. Compact shows Timer; the expanded dots select
   Timer or Now Playing without changing compact priority.
2. Start 1/5/10-minute presets and a custom duration from Timer & Stopwatch.
   Check Pause, Resume, Reset, Restart, and Done.
3. Switch to Stopwatch after Reset and check start/pause/resume/reset.
4. Let a short timer finish: one system alert and a brief completion animation.
5. Clear media and reset Timer: ordinary hover keeps the island collapsed.
6. Enable Reduce Motion in Accessibility: paging and completion use fades,
   without scale or interpolated ring movement.
7. Sleep during a countdown and wake: elapsed sleep counts; completion is
   delivered after the app resumes.
