import SwiftUI

public struct SurfaceMetrics: Equatable, Sendable {
    public var width: CGFloat
    public var height: CGFloat
    public var topRadius: CGFloat
    public var bottomRadius: CGFloat

    public init(width: CGFloat, height: CGFloat, topRadius: CGFloat, bottomRadius: CGFloat) {
        self.width = width
        self.height = height
        self.topRadius = topRadius
        self.bottomRadius = bottomRadius
    }

    public static let zero = Self(width: 0, height: 0, topRadius: 0, bottomRadius: 0)
}

public struct IslandShape: Shape {
    public var topRadius: CGFloat
    public var bottomRadius: CGFloat

    public init(topRadius: CGFloat, bottomRadius: CGFloat) {
        self.topRadius = topRadius
        self.bottomRadius = bottomRadius
    }

    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set { topRadius = newValue.first; bottomRadius = newValue.second }
    }

    public func path(in rect: CGRect) -> Path {
        let top = min(max(0, topRadius), min(rect.width, rect.height) / 2)
        let bottom = min(max(0, bottomRadius), min(rect.width, rect.height) / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + top, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - top, y: rect.minY + top), radius: top,
                    startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottom))
        path.addArc(center: CGPoint(x: rect.maxX - bottom, y: rect.maxY - bottom), radius: bottom,
                    startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bottom, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bottom, y: rect.maxY - bottom), radius: bottom,
                    startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + top))
        path.addArc(center: CGPoint(x: rect.minX + top, y: rect.minY + top), radius: top,
                    startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}
