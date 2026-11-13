import AppKit

public struct ScreenGeometry: Equatable, Sendable {
    public let id: String
    public let name: String
    public let frame: CGRect
    public let safeAreaTop: CGFloat
    public let auxiliaryLeft: CGRect
    public let auxiliaryRight: CGRect

    public init(id: String, name: String, frame: CGRect, safeAreaTop: CGFloat,
                auxiliaryLeft: CGRect = .zero, auxiliaryRight: CGRect = .zero) {
        self.id = id
        self.name = name
        self.frame = frame
        self.safeAreaTop = safeAreaTop
        self.auxiliaryLeft = auxiliaryLeft
        self.auxiliaryRight = auxiliaryRight
    }

    @MainActor
    public init(screen: NSScreen) {
        id = String((screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0)
        name = screen.localizedName
        frame = screen.frame
        safeAreaTop = screen.safeAreaInsets.top
        auxiliaryLeft = screen.auxiliaryTopLeftArea ?? .zero
        auxiliaryRight = screen.auxiliaryTopRightArea ?? .zero
    }

    public var hasNotch: Bool { safeAreaTop.isFinite && safeAreaTop > 0 }

    public static func select(from screens: [Self], preferredID: String, mainID: String?) -> Self? {
        screens.first { $0.id == preferredID }
            ?? screens.first { $0.hasNotch }
            ?? screens.first { $0.id == mainID }
            ?? screens.first
    }
}

public struct IslandLayout: Equatable, Sendable {
    public enum Mode: String, Sendable { case notch, pill }

    public let screen: ScreenGeometry
    public let mode: Mode
    public let notchRect: CGRect?
    public let usesEstimatedNotchWidth: Bool
    public let centerX: CGFloat
    public let topY: CGFloat
    public let collapsed: SurfaceMetrics
    public let compact: SurfaceMetrics
    public let expanded: SurfaceMetrics
    public let panelFrame: CGRect

    public init(screen: ScreenGeometry) {
        self.screen = screen
        mode = screen.hasNotch ? .notch : .pill
        let frame = screen.frame
        let depth = screen.hasNotch ? min(screen.safeAreaTop, 120) : 32
        let left = screen.auxiliaryLeft
        let right = screen.auxiliaryRight
        let validAreas = screen.hasNotch
            && !left.isEmpty && !right.isEmpty
            && frame.insetBy(dx: -1, dy: -1).contains(left)
            && frame.insetBy(dx: -1, dy: -1).contains(right)
            && abs(left.maxY - frame.maxY) <= 1
            && abs(right.maxY - frame.maxY) <= 1
            && abs(left.minY - (frame.maxY - depth)) <= 1
            && abs(right.minY - (frame.maxY - depth)) <= 1
            && right.minX - left.maxX >= 40
            && right.minX - left.maxX <= min(600, frame.width / 2)

        // Safe-area data still identifies a notch when auxiliary rectangles are
        // unavailable (for example during a display-mode transition).
        let width = validAreas ? right.minX - left.maxX : min(200, frame.width / 4)
        usesEstimatedNotchWidth = screen.hasNotch && !validAreas
        centerX = validAreas ? (left.maxX + right.minX) / 2 : frame.midX
        topY = frame.maxY - (screen.hasNotch ? 0 : 8)
        notchRect = screen.hasNotch
            ? CGRect(x: centerX - width / 2, y: frame.maxY - depth, width: width, height: depth)
            : nil

        let availableWidth = max(80, 2 * min(centerX - frame.minX, frame.maxX - centerX) - 24)
        let baseWidth = screen.hasNotch ? width + 12 : 168
        let baseHeight = depth + (screen.hasNotch ? 4 : 0)
        collapsed = SurfaceMetrics(width: min(baseWidth, availableWidth), height: baseHeight,
                                   topRadius: screen.hasNotch ? 6 : 16,
                                   bottomRadius: screen.hasNotch ? 10 : 16)
        compact = SurfaceMetrics(width: min(baseWidth + 160, availableWidth), height: baseHeight + 4,
                                 topRadius: screen.hasNotch ? 8 : 18, bottomRadius: 18)
        expanded = SurfaceMetrics(width: min(460, availableWidth), height: min(depth + 224, frame.height - 24),
                                  topRadius: screen.hasNotch ? 12 : 22, bottomRadius: 28)
        let canvasWidth = expanded.width + 40
        let canvasHeight = expanded.height + 32
        panelFrame = CGRect(x: centerX - canvasWidth / 2, y: topY - canvasHeight,
                            width: canvasWidth, height: canvasHeight)
    }

    public func metrics(for presentation: IslandPresentation) -> SurfaceMetrics {
        switch presentation {
        case .collapsed: collapsed
        case .compact: compact
        case .expanded: expanded
        }
    }

    public func surfaceRect(for metrics: SurfaceMetrics) -> CGRect {
        CGRect(x: centerX - metrics.width / 2, y: topY - metrics.height,
               width: metrics.width, height: metrics.height)
    }

    public func contains(_ point: CGPoint, metrics: SurfaceMetrics) -> Bool {
        let rect = surfaceRect(for: metrics)
        guard rect.contains(point) else { return false }
        let topRadius = min(max(0, metrics.topRadius), min(rect.width, rect.height) / 2)
        let bottomRadius = min(max(0, metrics.bottomRadius), min(rect.width, rect.height) / 2)
        let local = CGPoint(x: point.x - rect.minX, y: rect.maxY - point.y)
        for (center, radius) in [
            (CGPoint(x: topRadius, y: topRadius), topRadius),
            (CGPoint(x: rect.width - topRadius, y: topRadius), topRadius),
            (CGPoint(x: bottomRadius, y: rect.height - bottomRadius), bottomRadius),
            (CGPoint(x: rect.width - bottomRadius, y: rect.height - bottomRadius), bottomRadius)
        ] {
            let inCornerX = center.x <= rect.width / 2 ? local.x < center.x : local.x > center.x
            let inCornerY = center.y <= rect.height / 2 ? local.y < center.y : local.y > center.y
            if inCornerX && inCornerY && hypot(local.x - center.x, local.y - center.y) > radius {
                return false
            }
        }
        return true
    }
}
