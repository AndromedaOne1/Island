import Foundation
import IslandCore
import Testing

private func notchedScreen(id: String = "built-in", origin: CGPoint = .zero) -> ScreenGeometry {
    let frame = CGRect(origin: origin, size: CGSize(width: 1512, height: 982))
    return ScreenGeometry(id: id, name: "Built-in", frame: frame, safeAreaTop: 32,
                          auxiliaryLeft: CGRect(x: frame.minX, y: frame.maxY - 32, width: 663, height: 32),
                          auxiliaryRight: CGRect(x: frame.minX + 849, y: frame.maxY - 32, width: 663, height: 32))
}

@Test(arguments: [CGPoint.zero, CGPoint(x: -1800, y: 700), CGPoint(x: 600, y: -1200)])
func notchUsesGlobalScreenCoordinates(origin: CGPoint) {
    let screen = notchedScreen(origin: origin)
    let layout = IslandLayout(screen: screen)
    #expect(layout.mode == .notch)
    #expect(!layout.usesEstimatedNotchWidth)
    #expect(layout.notchRect == CGRect(x: origin.x + 663, y: origin.y + 950, width: 186, height: 32))
    #expect(layout.centerX == screen.frame.midX)
    #expect(layout.panelFrame.maxY == screen.frame.maxY)
    #expect(layout.collapsed.width == 198)
    #expect(layout.collapsed.height == 36)
    #expect(layout.expanded.width > layout.compact.width)
    #expect(layout.panelFrame.contains(layout.surfaceRect(for: layout.expanded)))
}

@Test func pillIsAvailableWithoutNotch() {
    let screen = ScreenGeometry(id: "external", name: "External", frame: CGRect(x: -1920, y: -200, width: 1920, height: 1080), safeAreaTop: 0)
    let layout = IslandLayout(screen: screen)
    #expect(layout.mode == .pill)
    #expect(layout.notchRect == nil)
    #expect(layout.centerX == -960)
    #expect(layout.panelFrame.maxY == 872)
    #expect(layout.collapsed.width == 168)
}

@Test func missingAuxiliaryAreasStillProtectNotch() {
    let screen = ScreenGeometry(id: "built-in", name: "Built-in", frame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32)
    let layout = IslandLayout(screen: screen)
    #expect(layout.mode == .notch)
    #expect(layout.usesEstimatedNotchWidth)
    #expect(layout.notchRect?.width == 200)
    #expect(layout.notchRect?.height == 32)
}

@Test func overlappingAuxiliaryAreasAreRejected() {
    let screen = ScreenGeometry(id: "invalid", name: "Invalid", frame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
                                auxiliaryLeft: CGRect(x: 0, y: 950, width: 800, height: 32),
                                auxiliaryRight: CGRect(x: 700, y: 950, width: 812, height: 32))
    #expect(IslandLayout(screen: screen).usesEstimatedNotchWidth)
}

@Test func screenSelectionRespectsPreferenceThenNotchThenMain() {
    let external = ScreenGeometry(id: "external", name: "External", frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), safeAreaTop: 0)
    let secondary = ScreenGeometry(id: "secondary", name: "Secondary", frame: external.frame, safeAreaTop: 0)
    let builtIn = notchedScreen()
    #expect(ScreenGeometry.select(from: [external, builtIn], preferredID: "", mainID: external.id)?.id == builtIn.id)
    #expect(ScreenGeometry.select(from: [external, builtIn], preferredID: external.id, mainID: builtIn.id)?.id == external.id)
    #expect(ScreenGeometry.select(from: [external, builtIn], preferredID: "disconnected", mainID: external.id)?.id == builtIn.id)
    #expect(ScreenGeometry.select(from: [external, secondary], preferredID: "", mainID: secondary.id)?.id == secondary.id)
    #expect(ScreenGeometry.select(from: [], preferredID: "", mainID: nil) == nil)
}

@Test func transparentCanvasAndRoundedCornersPassThrough() {
    let layout = IslandLayout(screen: notchedScreen())
    let rect = layout.surfaceRect(for: layout.expanded)
    #expect(layout.contains(CGPoint(x: rect.midX, y: rect.midY), metrics: layout.expanded))
    #expect(!layout.contains(CGPoint(x: rect.minX + 1, y: rect.minY + 1), metrics: layout.expanded))
    #expect(!layout.contains(CGPoint(x: rect.minX + 1, y: rect.maxY - 1), metrics: layout.expanded))
    #expect(!layout.contains(CGPoint(x: layout.panelFrame.minX + 1, y: rect.midY), metrics: layout.expanded))
    #expect(!layout.contains(CGPoint(x: rect.midX, y: layout.panelFrame.minY + 1), metrics: layout.expanded))
    #expect(layout.contains(CGPoint(x: layout.centerX, y: layout.topY - 1), metrics: layout.collapsed))
}

@Test func offCenterNotchDeterminesPanelAnchor() {
    let screen = ScreenGeometry(id: "offset", name: "Offset", frame: CGRect(x: 300, y: 100, width: 1512, height: 982), safeAreaTop: 32,
                                auxiliaryLeft: CGRect(x: 300, y: 1050, width: 600, height: 32),
                                auxiliaryRight: CGRect(x: 1086, y: 1050, width: 726, height: 32))
    let layout = IslandLayout(screen: screen)
    #expect(!layout.usesEstimatedNotchWidth)
    #expect(layout.centerX == 993)
    #expect(layout.panelFrame.midX == 993)
}

@Test func animatedSilhouetteKeepsTheEntireNotchCovered() {
    let layout = IslandLayout(screen: notchedScreen())
    let notch = layout.notchRect!
    for (start, end) in [(layout.collapsed, layout.compact), (layout.compact, layout.expanded)] {
        for step in 0...20 {
            let fraction = CGFloat(step) / 20
            let metrics = SurfaceMetrics(width: start.width + (end.width - start.width) * fraction,
                                         height: start.height + (end.height - start.height) * fraction,
                                         topRadius: start.topRadius + (end.topRadius - start.topRadius) * fraction,
                                         bottomRadius: start.bottomRadius + (end.bottomRadius - start.bottomRadius) * fraction)
            for x in [notch.minX + 0.5, notch.midX, notch.maxX - 0.5] {
                for y in [notch.minY + 0.5, notch.midY, notch.maxY - 0.5] {
                    #expect(layout.contains(CGPoint(x: x, y: y), metrics: metrics))
                }
            }
        }
    }
}
