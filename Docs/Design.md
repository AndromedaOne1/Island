# Design foundation

Core shell and Now Playing are accepted. This milestone changes their visual
language and shared components; the `IslandModule` contract and playback sources
are unchanged.

## Tokens and components

`Sources/IslandCore/Design/IslandDesign.swift` owns the palette, SF Pro system-font
roles, spacing, state dimensions, radii, artwork treatment, motion, marquee, and
settings measurements. Geometric ratios, protocol identifiers, media timing,
and safety limits remain with their owning models.

`IslandComponents.swift` provides a button style, title, subtitle, marquee,
progress bar, transport row, and empty-state component. Interactive controls
have hover and spring press feedback; read-only content adopts surface feedback.
The shell keeps its nonactivating behavior and routes input through the same
shape used for drawing. Pin and Settings live in quiet buttons in the expanded
wings outside the camera strip.

`ArtworkPalette.swift` provides continuous rounded artwork, shadows, and a small
weighted color sample. Black/white pixels contribute less to the accent. Sampling
and ImageIO decoding run in the existing background artwork task; late results
retain the existing track/lifetime guards. A soft radial gradient and playback
indicator use the cover's accent.

## Shape and motion

The notch remains anchored at the physical screen edge. The window and black
surface extend one point above it to remove the compositor's translucent first
pixel row. A one-point content inset preserves the original content coordinates.
Four points of overlap below the notch protect its lower edge. Pill mode retains
its detached position with no top overscan.

Collapsed/compact/expanded sizes derive from the measured notch width and depth.
Expanded width also respects the compact width on unusually wide notches.
The expanded lower corners use a 38-point radius, while the top radius stays
small at 10 points. Size and both radii animate together with one spring and a
stable panel canvas. The hit path includes the same top overscan as the renderer.

At the current Mac's measured 208 × 37.5-point notch:

| State | Visible size | Top / bottom radius |
| --- | --- | --- |
| Collapsed | 220 × 41.5 pt | 6 / 14 pt |
| Compact | 364 × 45.5 pt | 8 / 20 pt |
| Expanded | 420 × 261.5 pt | 10 / 38 pt |

Shell spring: response 0.46, damping 0.86. Content transition: 0.24 seconds,
opacity, scale from 0.96, and six-point blur. Button spring: response 0.28,
damping 0.72, pressed scale 0.90. Reduce Motion uses a short fade without spring
scaling, blur, automatic marquee, or state-bar motion. The design environment
defaults to the native accessibility value and permits a local preview override.

Long titles and artists are measured with their SF Pro font and tracking. They
hold for 1.8 seconds, move at 24 points per second with 0.45-second acceleration
and deceleration, and repeat through a second copy. Edge opacity ramps through
the loop boundary. Short text stays still; reduced motion uses an ellipsis.

## Visual verification

Real AppKit/SwiftUI panels were captured with `screencapture` on this notched Mac.
A temporary capture process uses the same `ShellView`, `IslandPanelController`,
and live Now Playing module. A neutral background isolates the silhouette and
keeps unrelated windows out of the images. The capture process and screenshots
remain in ignored `.cache/design`; production has no capture mode.

The first review found a heavy footer and a translucent one-pixel top edge.
The footer became quiet controls in the top wings, expanded height was reduced,
and top overscan removed the edge. Final checks include all three states, the
long-title loop boundary, empty content, and reduced-motion rendering. The
camera-width pixels at the top edge are checked for solid black.

The existing test suite plus notch-coverage checks passes in debug and release.
Coverage includes intermediate morph shapes on 186-, 410-, and 520-point notches,
pill fallback, rounded input regions, and existing playback/lifecycle behavior.
The bundle script validates metadata and ad-hoc signatures.

Automatic pointer injection is unavailable on this host; no Accessibility prompt
was requested. Real hover/press, rapid retargeting, native accessibility changes,
and Pin/Settings input remain in the owner's manual check:

- Hover and leave repeatedly; watch size, corner radii, and content transitions.
- Check the physical notch edge for a bright line or gap.
- Hover/press transport buttons, pin, and settings; check their hit areas.
- Play/pause and change tracks; watch the cover, accent, title, and progress.
- Leave a long title open for a full loop; check both faded edges.
- Enable Reduce Motion in macOS; check static text and indicator behavior.
- Stop playback or disable Now Playing; check the empty expanded state.
