import AppKit
import Combine
import SwiftUI

@MainActor
public final class TimerModule: IslandModule {
    public let id = "timer"
    public let title = "Timer & Stopwatch"
    public let priority = 200
    public let model: TimerModel
    @Published public private(set) var isCelebrating = false
    @Published private var isStarted = false
    public var isActive: Bool { isStarted && model.isActive }
    private let completion: () -> Void
    private let automaticallyTick: Bool
    private var ticker: Task<Void, Never>?
    private var celebrationTask: Task<Void, Never>?
    private var subscriptions: Set<AnyCancellable> = []

    public init(model: TimerModel = TimerModel(), automaticallyTick: Bool = true,
                completion: @escaping () -> Void = { NSSound.beep() }) {
        self.model = model
        self.automaticallyTick = automaticallyTick
        self.completion = completion
        model.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.objectWillChange.send() }
        }.store(in: &subscriptions)
        model.$phase.removeDuplicates().sink { [weak self] phase in self?.phaseChanged(phase) }
            .store(in: &subscriptions)
    }

    public func compactView(for position: CompactPosition) -> AnyView {
        AnyView(CompactTimerView(module: self, position: position))
    }
    public func expandedView() -> AnyView { AnyView(ExpandedTimerView(module: self)) }

    public func start() {
        guard !isStarted else { return }
        isStarted = true
        if model.phase == .running { startTicker() }
    }

    public func stop() {
        guard isStarted else { return }
        isStarted = false
        ticker?.cancel(); ticker = nil
        celebrationTask?.cancel(); celebrationTask = nil
        isCelebrating = false
        model.pause()
    }

    private func startTicker() {
        guard automaticallyTick, ticker == nil else { return }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(IslandDesign.Timer.tickInterval)) }
                catch { return }
                guard !Task.isCancelled, let self, self.isStarted else { return }
                self.model.advance()
            }
        }
    }

    private func phaseChanged(_ phase: TimerPhase) {
        guard isStarted else { return }
        if phase == .running {
            startTicker()
        } else {
            ticker?.cancel(); ticker = nil
        }
        if phase == .finished {
            completion()
            isCelebrating = true
            celebrationTask?.cancel()
            celebrationTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(IslandDesign.Timer.celebrationDuration)) }
                catch { return }
                guard !Task.isCancelled else { return }
                self?.isCelebrating = false
                self?.celebrationTask = nil
            }
        } else {
            celebrationTask?.cancel(); celebrationTask = nil
            isCelebrating = false
        }
    }
}
