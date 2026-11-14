import IslandCore
import Testing

@Test @MainActor func shortHoverDoesNotExpand() async throws {
    let model = IslandInteraction()
    model.hoverDelay = 0.025
    model.setHasActiveModule(true)
    model.pointerEntered()
    #expect(model.presentation == .compact)
    model.pointerExited()
    try await Task.sleep(for: .milliseconds(70))
    #expect(model.presentation == .compact)
}

@Test @MainActor func hoverExpandsThenLeavingCollapses() async throws {
    let model = IslandInteraction()
    model.hoverDelay = 0.01
    model.collapseDelay = 0.01
    model.setHasActiveModule(true)
    model.pointerEntered()
    try await Task.sleep(for: .milliseconds(60))
    #expect(model.presentation == .expanded)
    model.pointerExited()
    #expect(model.presentation == .expanded)
    try await Task.sleep(for: .milliseconds(60))
    #expect(model.presentation == .compact)
}

@Test @MainActor func leavingHoverRestoresCompactPreview() async throws {
    let model = IslandInteraction()
    model.hoverDelay = 0.01
    model.collapseDelay = 0.01
    model.setCompactPreview(true)
    model.pointerEntered()
    try await Task.sleep(for: .milliseconds(60))
    #expect(model.presentation == .expanded)
    model.pointerExited()
    try await Task.sleep(for: .milliseconds(60))
    #expect(model.presentation == .compact)
}

@Test @MainActor func dismissCancelsHoverUntilPointerReenters() async throws {
    let model = IslandInteraction()
    model.hoverDelay = 0.01
    model.setCompactPreview(true)
    #expect(model.presentation == .compact)
    model.pointerEntered()
    model.dismiss()
    model.pointerEntered()
    try await Task.sleep(for: .milliseconds(60))
    #expect(model.presentation == .compact)
    model.pointerExited()
    model.pointerEntered()
    try await Task.sleep(for: .milliseconds(60))
    #expect(model.presentation == .expanded)
}

@Test @MainActor func reentryCancelsDelayedCollapse() async throws {
    let model = IslandInteraction()
    model.hoverDelay = 0.01
    model.collapseDelay = 0.02
    model.setHasActiveModule(true)
    model.pointerEntered()
    try await Task.sleep(for: .milliseconds(60))
    model.pointerExited()
    model.pointerEntered()
    try await Task.sleep(for: .milliseconds(60))
    #expect(model.presentation == .expanded)
}

@Test @MainActor func resetCancelsPendingExpansionAndClearsHover() async throws {
    let model = IslandInteraction()
    model.hoverDelay = 0.01
    model.setHasActiveModule(true)
    model.pointerEntered()
    model.reset()
    try await Task.sleep(for: .milliseconds(60))
    #expect(model.presentation == .compact)
    #expect(!model.isHovered)
    model.pointerEntered()
    try await Task.sleep(for: .milliseconds(60))
    #expect(model.presentation == .expanded)
    model.reset()
    #expect(model.presentation == .compact)
    #expect(!model.isHovered)
}

@Test @MainActor func activeModuleOwnsRestingCompactState() async throws {
    let model = IslandInteraction()
    model.hoverDelay = 0.01
    model.collapseDelay = 0.01
    model.setHasActiveModule(true)
    #expect(model.presentation == .compact)
    model.pointerEntered()
    try await Task.sleep(for: .milliseconds(60))
    #expect(model.presentation == .expanded)
    model.setHasActiveModule(false)
    #expect(model.presentation == .collapsed)
    model.pointerExited()
    try await Task.sleep(for: .milliseconds(60))
    #expect(model.presentation == .collapsed)
}

@Test @MainActor func idleHoverStaysCollapsedAndActivationCanExpandUnderPointer() async throws {
    let model = IslandInteraction()
    model.hoverDelay = 0.01
    model.pointerEntered()
    try await Task.sleep(for: .milliseconds(50))
    #expect(model.presentation == .collapsed)
    model.setHasActiveModule(true)
    try await Task.sleep(for: .milliseconds(50))
    #expect(model.presentation == .expanded)
    model.setHasActiveModule(false)
    #expect(model.presentation == .collapsed)
    try await Task.sleep(for: .milliseconds(50))
    #expect(model.presentation == .collapsed)
}
