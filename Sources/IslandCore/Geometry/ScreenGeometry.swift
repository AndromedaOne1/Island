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
        let depth = screen.hasNotch ? min(screen.safeAreaTop, IslandDesign.Layout.maximumNotchDepth) : IslandDesign.Layout.pillHeight
        let left = screen.auxiliaryLeft
        let right = screen.auxiliaryRight
        let validAreas = screen.hasNotch
            && !left.isEmpty && !right.isEmpty
            && frame.insetBy(dx: -IslandDesign.Layout.screenTolerance, dy: -IslandDesign.Layout.screenTolerance).contains(left)
            && frame.insetBy(dx: -IslandDesign.Layout.screenTolerance, dy: -IslandDesign.Layout.screenTolerance).contains(right)
            && abs(left.maxY - frame.maxY) <= IslandDesign.Layout.screenTolerance
            && abs(right.maxY - frame.maxY) <= IslandDesign.Layout.screenTolerance
            && abs(left.minY - (frame.maxY - depth)) <= IslandDesign.Layout.screenTolerance
            && abs(right.minY - (frame.maxY - depth)) <= IslandDesign.Layout.screenTolerance
            && right.minX - left.maxX >= IslandDesign.Layout.minimumNotchWidth
            && right.minX - left.maxX <= min(IslandDesign.Layout.maximumNotchWidth, frame.width / 2)

        // Safe-area data still identifies a notch when auxiliary rectangles are
        // unavailable (for example during a display-mode transition).
        let width = validAreas ? right.minX - left.maxX : min(IslandDesign.Layout.estimatedNotchWidth, frame.width / 4)
        usesEstimatedNotchWidth = screen.hasNotch && !validAreas
        centerX = validAreas ? (left.maxX + right.minX) / 2 : frame.midX
        topY = frame.maxY - (screen.hasNotch ? 0 : IslandDesign.Layout.pillTopOffset)
        notchRect = screen.hasNotch
            ? CGRect(x: centerX - width / 2, y: frame.maxY - depth, width: width, height: depth)
            : nil

        let availableWidth = max(IslandDesign.Layout.minimumAvailableWidth, 2 * min(centerX - frame.minX, frame.maxX - centerX) - IslandDesign.Spacing.content)
        let baseWidth = screen.hasNotch ? width + IslandDesign.Layout.notchWidthPadding : IslandDesign.Layout.pillWidth
        let baseHeight = depth + (screen.hasNotch ? IslandDesign.Layout.notchBottomOverlap : 0)
        collapsed = SurfaceMetrics(width: min(baseWidth, availableWidth), height: baseHeight,
                                   topRadius: screen.hasNotch ? IslandDesign.Layout.collapsedTopRadius : IslandDesign.Layout.pillCollapsedRadius,
                                   bottomRadius: screen.hasNotch ? IslandDesign.Layout.collapsedBottomRadius : IslandDesign.Layout.pillCollapsedRadius)
        compact = SurfaceMetrics(width: min(baseWidth + IslandDesign.Layout.compactExtraWidth, availableWidth), height: baseHeight + IslandDesign.Layout.compactExtraHeight,
                                 topRadius: screen.hasNotch ? IslandDesign.Layout.compactTopRadius : IslandDesign.Layout.pillCompactRadius, bottomRadius: IslandDesign.Layout.compactBottomRadius)
        expanded = SurfaceMetrics(width: min(max(IslandDesign.Layout.expandedWidth, compact.width), availableWidth), height: min(depth + IslandDesign.Layout.expandedBodyHeight, frame.height - IslandDesign.Spacing.content),
                                  topRadius: screen.hasNotch ? IslandDesign.Layout.expandedTopRadius : IslandDesign.Layout.pillExpandedRadius, bottomRadius: IslandDesign.Layout.expandedBottomRadius)
        let canvasWidth = max(expanded.width, compact.width) + IslandDesign.Layout.canvasHorizontalMargin
        let canvasHeight = expanded.height + IslandDesign.Layout.canvasVerticalMargin
        panelFrame = CGRect(x: centerX - canvasWidth / 2, y: topY - canvasHeight,
                            width: canvasWidth,
                            height: canvasHeight + (screen.hasNotch ? IslandDesign.Layout.notchTopBleed : 0))
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
        let local = CGPoint(x: point.x - rect.minX, y: rect.maxY - point.y)
        return IslandShape(topRadius: metrics.topRadius, bottomRadius: metrics.bottomRadius,
                           topBleed: mode == .notch ? IslandDesign.Layout.notchTopBleed : 0)
            .path(in: CGRect(origin: .zero, size: rect.size)).contains(local)
    }
}
