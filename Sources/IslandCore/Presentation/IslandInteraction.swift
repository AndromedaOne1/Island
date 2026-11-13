import Combine
import Foundation

public enum IslandPresentation: String, Sendable { case collapsed, compact, expanded }

@MainActor
public final class IslandInteraction: ObservableObject {
    @Published public private(set) var presentation: IslandPresentation = .collapsed
    @Published public private(set) var isPinned = false
    @Published public private(set) var isCompactPreviewEnabled = false
    public private(set) var isHovered = false
    public var hoverDelay: TimeInterval = 0.25
    public var collapseDelay: TimeInterval = 0.3

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
        guard !isPinned && !hoverExpanded else { return }
        let delay = max(0, hoverDelay)
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, self.isHovered else { return }
            self.hoverExpanded = true
            self.refreshPresentation()
        }
    }

    public func pointerExited() {
        guard isHovered else { return }
        isHovered = false
        hoverTask?.cancel()
        hoverTask = nil
        guard !isPinned else { return }
        let delay = max(0, collapseDelay)
        collapseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, !self.isHovered else { return }
            self.hoverExpanded = false
            self.refreshPresentation()
        }
    }

    public func togglePin() {
        if isPinned {
            dismiss()
        } else {
            cancelPendingTransitions()
            isPinned = true
            refreshPresentation()
        }
    }

    public func dismiss() {
        cancelPendingTransitions()
        isPinned = false
        hoverExpanded = false
        refreshPresentation()
    }

    public func reset() {
        isHovered = false
        dismiss()
    }

    public func setCompactPreview(_ enabled: Bool) {
        isCompactPreviewEnabled = enabled
        refreshPresentation()
    }

    public func setHasActiveModule(_ active: Bool) {
        hasActiveModule = active
        refreshPresentation()
    }

    private func refreshPresentation() {
        let next: IslandPresentation = isPinned || hoverExpanded
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
