import Combine
import Foundation

public enum TimerMode: String, CaseIterable, Sendable { case countdown, stopwatch }
public enum TimerPhase: Equatable, Sendable { case idle, running, paused, finished }

public enum TimerClock {
    private static let origin = ContinuousClock.now
    public static func now() -> TimeInterval {
        let parts = origin.duration(to: ContinuousClock.now).components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }
}

@MainActor
public final class TimerModel: ObservableObject {
    public static let maximumDuration: TimeInterval = 86_400
    @Published public private(set) var mode: TimerMode = .countdown
    @Published public private(set) var phase: TimerPhase = .idle
    @Published public private(set) var duration: TimeInterval = 60
    @Published public private(set) var elapsed: TimeInterval = 0
    private let clock: () -> TimeInterval
    private var runStartedAt: TimeInterval?
    private var elapsedBeforeRun: TimeInterval = 0

    public init(clock: @escaping () -> TimeInterval = TimerClock.now) { self.clock = clock }

    public var remaining: TimeInterval { max(0, duration - elapsed) }
    public var progress: Double { mode == .countdown ? min(1, max(0, remaining / duration)) : 1 }
    public var isActive: Bool { phase != .idle }

    @discardableResult
    public func setMode(_ mode: TimerMode) -> Bool {
        guard phase == .idle else { return false }
        self.mode = mode
        return true
    }

    @discardableResult
    public func setDuration(_ seconds: TimeInterval) -> Bool {
        guard phase == .idle, seconds.isFinite, seconds >= 1, seconds <= Self.maximumDuration else { return false }
        duration = seconds
        return true
    }

    @discardableResult
    public func begin() -> Bool {
        guard phase == .idle || phase == .paused else { return false }
        let now = clock()
        guard now.isFinite else { return false }
        elapsedBeforeRun = elapsed
        runStartedAt = now
        phase = .running
        return true
    }

    public func pause() {
        guard phase == .running else { return }
        advance()
        guard phase == .running else { return }
        elapsedBeforeRun = elapsed
        runStartedAt = nil
        phase = .paused
    }

    public func reset() {
        runStartedAt = nil
        elapsedBeforeRun = 0
        elapsed = 0
        phase = .idle
    }

    public func advance() {
        guard phase == .running, let start = runStartedAt else { return }
        let now = clock()
        guard now.isFinite else { return }
        // ContinuousClock includes sleep and is unaffected by wall-clock changes.
        let next = max(elapsed, elapsedBeforeRun + max(0, now - start))
        if mode == .countdown && next >= duration {
            elapsed = duration
            runStartedAt = nil
            phase = .finished
        } else if elapsed != next {
            elapsed = next
        }
    }
}

public enum TimerTime {
    public static func display(_ seconds: TimeInterval, countdown: Bool = false) -> String {
        let bounded = seconds.isFinite ? min(359_999_999, max(0, seconds)) : 0
        let whole = Int(countdown ? ceil(bounded) : floor(bounded))
        if whole >= 3600 { return String(format: "%d:%02d:%02d", whole / 3600, whole / 60 % 60, whole % 60) }
        return String(format: "%02d:%02d", whole / 60, whole % 60)
    }

    public static func compact(_ seconds: TimeInterval, countdown: Bool) -> String {
        let bounded = seconds.isFinite ? min(359_999_999, max(0, seconds)) : 0
        let whole = Int(countdown ? ceil(bounded) : floor(bounded))
        if whole >= 360_000 { return "\(whole / 3600)h" }
        if whole >= 3600 { return String(format: "%d:%02dh", whole / 3600, whole / 60 % 60) }
        return display(bounded, countdown: countdown)
    }
}
