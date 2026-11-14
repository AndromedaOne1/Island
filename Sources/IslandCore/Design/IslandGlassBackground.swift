import AppKit
import SwiftUI

public struct IslandGlassBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init() {}

    public var body: some View {
        Group {
            if reduceTransparency {
                IslandDesign.Colors.background
            } else {
                IslandBackdrop()
                    .overlay(IslandDesign.Colors.background.opacity(IslandDesign.Glass.tintOpacity))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct IslandBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
