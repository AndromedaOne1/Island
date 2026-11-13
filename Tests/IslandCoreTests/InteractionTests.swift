import IslandCore
import Testing

@Test @MainActor func shortHoverDoesNotExpand() async throws {
    let model = IslandInteraction()
    model.hoverDelay = 0.025
    model.pointerEntered()
    #expect(model.presentation == .collapsed)
    model.pointerExited()
    try await Task.sleep(for: .milliseconds(70))
    #expect(model.presentation == .collapsed)
}

@Test @MainActor func hoverExpandsThenLeavingCollapses() async throws {
    let model = IslandInteraction()
    model.hoverDelay = 0.01
    model.collapseDelay = 0.01
    model.pointerEntered()
    try await Task.sleep(for: .milliseconds(60))
    #expect(model.presentation == .expanded)
    #expect(!model.isPinned)
    model.pointerExited()
    #expect(model.presentation == .expanded)
    try await Task.sleep(for: .milliseconds(60))
    #expect(model.presentation == .collapsed)
}

@Test @MainActor func pinSurvivesPointerExitAndOutsideClickDismisses() async throws {
    let model = IslandInteraction()
    model.collapseDelay = 0.01
    model.pointerEntered()
    model.togglePin()
    model.pointerExited()
    try await Task.sleep(for: .milliseconds(60))
    #expect(model.presentation == .expanded)
    #expect(model.isPinned)
    model.dismiss()
    #expect(model.presentation == .collapsed)
    #expect(!model.isPinned)
}

@Test @MainActor func unpinCancelsHoverAndRestoresCompactPreview() async throws {
    let model = IslandInteraction()
    model.hoverDelay = 0.01
    model.setCompactPreview(true)
    #expect(model.presentation == .compact)
    model.pointerEntered()
    model.togglePin()
    model.togglePin()
    try await Task.sleep(for: .milliseconds(60))
    #expect(model.presentation == .compact)
    #expect(!model.isPinned)
}

@Test @MainActor func reentryCancelsDelayedCollapse() async throws {
    let model = IslandInteraction()
    model.collapseDelay = 0.02
    model.pointerEntered()
    model.togglePin()
    model.dismiss()
    model.hoverDelay = 0.01
    model.pointerExited()
    model.pointerEntered()
    try await Task.sleep(for: .milliseconds(60))
    model.pointerExited()
    model.pointerEntered()
    try await Task.sleep(for: .milliseconds(60))
    #expect(model.presentation == .expanded)
}

@Test @MainActor func resetCancelsPendingExpansionAndClearsPin() async throws {
    let model = IslandInteraction()
    model.hoverDelay = 0.01
    model.pointerEntered()
    model.reset()
    try await Task.sleep(for: .milliseconds(60))
    #expect(model.presentation == .collapsed)
    #expect(!model.isHovered)
    model.togglePin()
    model.reset()
    #expect(!model.isPinned)
}

@Test @MainActor func activeModuleOwnsRestingCompactState() {
    let model = IslandInteraction()
    model.setHasActiveModule(true)
    #expect(model.presentation == .compact)
    model.togglePin()
    model.setHasActiveModule(false)
    #expect(model.presentation == .expanded)
    model.dismiss()
    #expect(model.presentation == .collapsed)
}
