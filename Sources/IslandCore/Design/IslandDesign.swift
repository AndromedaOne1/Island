import AppKit
import SwiftUI

/// Shared visual language. Geometric ratios and media/protocol limits are not design tokens.
public enum IslandDesign {
    public enum Colors {
        public static let background = Color.black
        public static let primary = Color.white.opacity(0.96)
        public static let primaryHover = Color.white
        public static let secondary = Color.white.opacity(0.62)
        public static let secondaryHover = Color.white.opacity(0.76)
        public static let tertiary = Color.white.opacity(0.38)
        public static let surface = Color.white.opacity(0.08)
        public static let hover = Color.white.opacity(0.13)
        public static let pressed = Color.white.opacity(0.19)
        public static let warning = Color.orange
        public static let settingsSecondary = Color.secondary
        public static let disabledOpacity = 0.35
        public static let pressedOpacity = 0.88
    }

    public enum Spacing {
        public static let hairline: CGFloat = 1
        public static let micro: CGFloat = 3
        public static let tight: CGFloat = 4
        public static let small: CGFloat = 8
        public static let regular: CGFloat = 12
        public static let medium: CGFloat = 16
        public static let large: CGFloat = 20
        public static let content: CGFloat = 20
        public static let wide: CGFloat = 32
    }

    public enum Layout {
        public static let notchWidthPadding: CGFloat = 8
        public static let notchBottomOverlap: CGFloat = 2
        public static let notchTopBleed: CGFloat = 1
        public static let compactExtraWidth: CGFloat = 112
        public static let compactExtraHeight: CGFloat = 2
        public static let expandedWidth: CGFloat = 384
        public static let expandedBodyHeight: CGFloat = 200
        public static let collapsedTopRadius: CGFloat = 4
        public static let collapsedBottomRadius: CGFloat = 10
        public static let compactTopRadius: CGFloat = 6
        public static let compactBottomRadius: CGFloat = 16
        public static let expandedTopRadius: CGFloat = 10
        public static let expandedBottomRadius: CGFloat = 34
        public static let pillWidth: CGFloat = 168
        public static let pillHeight: CGFloat = 32
        public static let pillTopOffset: CGFloat = 8
        public static let pillCollapsedRadius: CGFloat = 16
        public static let pillCompactRadius: CGFloat = 20
        public static let pillExpandedRadius: CGFloat = 30
        public static let pillContentTop: CGFloat = 16
        public static let pillWingGap: CGFloat = 76
        public static let canvasHorizontalMargin: CGFloat = 40
        public static let canvasVerticalMargin: CGFloat = 32
        public static let minimumAvailableWidth: CGFloat = 80
        public static let maximumNotchDepth: CGFloat = 120
        public static let minimumNotchWidth: CGFloat = 40
        public static let maximumNotchWidth: CGFloat = 600
        public static let estimatedNotchWidth: CGFloat = 200
        public static let screenTolerance: CGFloat = 1
    }

    public enum Glass {
        public static let tintOpacity = 0.55
        public static let notchFadeHeight: CGFloat = 32
    }

    public enum Typography {
        public enum Role: Sendable {
            case title, subtitle, caption, label, symbol
            public var size: CGFloat {
                switch self {
                case .title: 17
                case .subtitle: 13
                case .caption: 11
                case .label: 12
                case .symbol: 20
                }
            }
            public var lineHeight: CGFloat {
                switch self {
                case .title: 23
                case .subtitle: 18
                case .caption: 15
                case .label: 17
                case .symbol: 24
                }
            }
            public var font: Font {
                .system(size: size, weight: self == .title ? .semibold : .medium, design: .default)
            }
            public var appKitFont: NSFont {
                .systemFont(ofSize: size, weight: self == .title ? .semibold : .medium)
            }
        }
        public static let titleTracking: CGFloat = -0.25
        public static let time = Font.system(size: Role.caption.size, weight: .medium, design: .monospaced)
    }

    public enum Motion {
        public static let shellResponse = 0.32
        public static let shellDamping = 0.88
        public static let pressResponse = 0.28
        public static let pressDamping = 0.72
        public static let hoverDuration = 0.16
        public static let contentDuration = 0.18
        public static let reducedDuration = 0.14
        public static let hoverDelay = 0.05
        public static let collapseDelay = 0.3
        public static let minimumHoverDelay = 0.02
        public static let maximumHoverDelay = 1.5
        public static let hoverDelayStep = 0.01
        public static let frameInterval = 1.0 / 30.0
        public static let progressInterval = 0.25
        public static let contentScale: CGFloat = 0.96
        public static let contentBlur: CGFloat = 6
        public static let pressedScale: CGFloat = 0.90
        public static let surfacePressedScale: CGFloat = 0.985

        public static func shell(reduceMotion: Bool) -> Animation {
            reduceMotion ? .easeOut(duration: reducedDuration)
                : .spring(response: shellResponse, dampingFraction: shellDamping)
        }
        public static func press(reduceMotion: Bool) -> Animation {
            reduceMotion ? .easeOut(duration: reducedDuration)
                : .spring(response: pressResponse, dampingFraction: pressDamping)
        }
        public static let hover = Animation.easeOut(duration: hoverDuration)
        public static let content = Animation.easeInOut(duration: contentDuration)
    }

    public enum Artwork {
        public static let compactSize: CGFloat = 24
        public static let expandedSize: CGFloat = 64
        public static let cornerRatio: CGFloat = 0.22
        public static let placeholderSymbolRatio: CGFloat = 0.40
        public static let shadowRadius: CGFloat = 12
        public static let shadowOffset: CGFloat = 5
        public static let shadowOpacity = 0.40
        public static let hoverBrightness = 0.025
        public static let thumbnailPixels = 256
        public static let palettePixels = 12
        public static let minimumPaletteBrightness = 0.12
        public static let maximumPaletteBrightness = 0.95
        public static let minimumPaletteSaturation = 0.10
        public static let paletteSaturationBoost = 1.25
        public static let accentBrightnessFloor = 0.58
        public static let backdropOpacity = 0.16
        public static let backdropRadius: CGFloat = 240
        public static let backdropAspect: CGFloat = 1.5
    }

    public enum Control {
        public static let padding: CGFloat = 10
        public static let transportSize: CGFloat = 40
        public static let primarySize: CGFloat = 48
        public static let transportSymbol: CGFloat = 18
        public static let primarySymbol: CGFloat = 22
        public static let placeholderSymbol: CGFloat = 28
        public static let placeholderSize: CGFloat = 52
    }

    public enum Progress {
        public static let height: CGFloat = 3
        public static let trackOpacity = 0.18
        public static let hoverTrackOpacity = 0.25
    }

    public enum Marquee {
        public static let speed: CGFloat = 24
        public static let holdDuration = 1.8
        public static let rampDuration = 0.45
        public static let gap: CGFloat = 32
        public static let fadeWidth: CGFloat = 12
    }

    public enum Indicator {
        public static let bars = 4
        public static let width: CGFloat = 24
        public static let height: CGFloat = 20
        public static let barWidth: CGFloat = 2.5
        public static let restingHeight: CGFloat = 4
        public static let amplitude: CGFloat = 12
        public static let frequency = 5.0
        public static let phaseOffset = 1.3
    }

    public enum Settings {
        public static let size = CGSize(width: 480, height: 560)
        public static let delayLabelWidth: CGFloat = 40
    }

    public enum Modules {
        public static let navigationHeight: CGFloat = 24
        public static let dotSize: CGFloat = 5
        public static let contentHeight: CGFloat = 162
    }

    public enum Timer {
        public static let accent = Color.orange
        public static let stopwatchAccent = Color.mint
        public static let tickInterval = 0.1
        public static let celebrationDuration = 1.2
        public static let celebrationScale: CGFloat = 1.04
        public static let glowOpacity = 0.12
        public static let compactRingSize: CGFloat = 24
        public static let ringSize: CGFloat = 44
        public static let ringWidth: CGFloat = 2.5
        public static let modeHeight: CGFloat = 22
        public static let headerHeight: CGFloat = 50
        public static let presetHeight: CGFloat = 26
        public static let stepperLabelWidth: CGFloat = 36
        public static let minimumTextScale: CGFloat = 0.7
        public static let timeFont = Font.system(size: 32, weight: .light, design: .rounded)
        public static let windowSize = CGSize(width: 384, height: 224)
    }
}
