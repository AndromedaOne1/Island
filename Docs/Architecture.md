# Core shell architecture

Status: Swift package to `Island.app` and the `IslandModule` contract confirmed.
Step 1 is implemented; physical-notch and Space/fullscreen behavior await
hardware validation before feature modules are added.

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
  IslandApp/
    App/               App delegate, menu bar item, and settings window
    Views/             Shell content and settings interface
Tests/
  IslandCoreTests/     Geometry, interaction, and module-selection tests
Resources/
  Info.plist           App bundle metadata; macOS 14 minimum
Scripts/
  build-app.sh         Build, bundle, and ad-hoc sign Island.app
  run.sh               Build and launch the app bundle
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
observable updates to the shell. The highest-priority enabled active module owns
the compact and expanded content. Equal priorities use stable identifier order.
Only the module boundary erases view types; each module can use concrete SwiftUI
views internally. Compact views occupy separate wings outside the notch.

The first milestone registers no live modules. An empty expanded view offers
shell controls, and a menu command can temporarily preview the compact layout.

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
- Hover expands after a configurable delay. Leaving collapses after a short delay.
  Clicking pins or unpins the expanded island; an outside click dismisses it.
- A custom `Shape` animates its top and bottom corner radii alongside its size.
- Opening Settings is an explicit user action and activates the settings window.
  Showing and interacting with the overlay never activates the application.

`ScreenGeometry` snapshots AppKit data into values for geometry tests.
`IslandLayout` anchors its stable canvas at the screen's top edge, independent
of `visibleFrame` and the menu bar's autohide state. Valid auxiliary areas define
the notch gap; when a notched screen temporarily lacks valid areas, a centered
200-point estimate protects the camera strip. Only screens with no top safe-area
inset use the detached pill, eight points below the top edge.

`IslandInteraction` cancels pending hover and collapse tasks on dismiss/reset.
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
Expose module toggles through the registry when modules are added. Launch at login
uses public `SMAppService.mainApp` and changes only when its toggle is used.

No private APIs are needed for the core shell. Now Playing research and a separate
decision about supported providers must precede its implementation. Timer,
Calendar, Battery, HUD, shelf, and device-use features remain later milestones.

## Validation

Build the app bundle with the installed Swift toolchain. Test notch/fallback
geometry on offset and negative-coordinate screens, invalid auxiliary geometry,
module priority and lifecycle, and hover/click state transitions. Launch the
bundle and check panel flags, active application, and screen placement. Manual
hardware testing must cover the physical notch, menu interaction, fullscreen,
Spaces, external monitor changes, animation, and launch-at-login behavior.
