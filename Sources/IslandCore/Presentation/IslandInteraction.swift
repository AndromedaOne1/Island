import Combine
import Foundation

public enum IslandPresentation: String, Sendable { case collapsed, compact, expanded }

@MainActor
public final class IslandInteraction: ObservableObject {
    @Published public private(set) var presentation: IslandPresentation = .collapsed
    @Published public private(set) var isCompactPreviewEnabled = false
    public private(set) var isHovered = false
    public var hoverDelay: TimeInterval = IslandDesign.Motion.hoverDelay
    public var collapseDelay: TimeInterval = IslandDesign.Motion.collapseDelay

    private var hasActiveModule = false
    private var hoverExpanded = false
    private var hoverTask: Task<Void, Never>?
    private var collapseTask: Task<Void, Never>?

    public init() {}

    public func pointerEntered() {
        guard !isHovered else { return }
        isHovered = true
        collapseTask?.cancel()
        collapseTask = nil
        scheduleExpansion()
    }

    private func scheduleExpansion() {
        guard isHovered, !hoverExpanded, hasActiveModule || isCompactPreviewEnabled else { return }
        hoverTask?.cancel()
        let delay = max(0, hoverDelay)
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, self.isHovered,
                  self.hasActiveModule || self.isCompactPreviewEnabled else { return }
            self.hoverExpanded = true
            self.refreshPresentation()
        }
    }

    public func pointerExited() {
        guard isHovered else { return }
        isHovered = false
        hoverTask?.cancel()
        hoverTask = nil
        let delay = max(0, collapseDelay)
        collapseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, !self.isHovered else { return }
            self.hoverExpanded = false
            self.refreshPresentation()
        }
    }

    public func dismiss() {
        cancelPendingTransitions()
        hoverExpanded = false
        refreshPresentation()
    }

    public func reset() {
        isHovered = false
        dismiss()
    }

    public func setCompactPreview(_ enabled: Bool) {
        guard isCompactPreviewEnabled != enabled else { return }
        isCompactPreviewEnabled = enabled
        updateAvailability()
    }

    public func setHasActiveModule(_ active: Bool) {
        guard hasActiveModule != active else { return }
        hasActiveModule = active
        updateAvailability()
    }

    private func updateAvailability() {
        if !hasActiveModule && !isCompactPreviewEnabled {
            dismiss()
        } else {
            scheduleExpansion()
        }
        refreshPresentation()
    }

    private func refreshPresentation() {
        let next: IslandPresentation = hoverExpanded
            ? .expanded : (hasActiveModule || isCompactPreviewEnabled ? .compact : .collapsed)
        if presentation != next { presentation = next }
    }

    private func cancelPendingTransitions() {
        hoverTask?.cancel()
        collapseTask?.cancel()
        hoverTask = nil
        collapseTask = nil
    }
}
