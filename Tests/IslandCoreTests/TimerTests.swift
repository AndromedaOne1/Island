import Foundation
import IslandCore
import Testing

@MainActor private final class TestTimerClock {
    var now: TimeInterval = 0
}

@Test @MainActor func countdownPauseResumeAndResetUseElapsedTime() {
    let clock = TestTimerClock()
    let model = TimerModel(clock: { clock.now })
    #expect(model.setDuration(60))
    #expect(model.begin())
    clock.now = 12.25
    model.advance()
    #expect(model.remaining == 47.75)
    #expect(abs(model.progress - 47.75 / 60) < 0.00001)
    clock.now = 15
    model.pause()
    clock.now = 200
    model.advance()
    #expect(model.phase == .paused)
    #expect(model.elapsed == 15)
    #expect(model.begin())
    clock.now = 210
    model.advance()
    #expect(model.elapsed == 25)
    model.reset()
    #expect(model.phase == .idle)
    #expect(!model.isActive)
    #expect(model.elapsed == 0)
    #expect(model.duration == 60)
}

@Test @MainActor func countdownCompletesOnceAfterClockJumpAndCanRestart() {
    let clock = TestTimerClock()
    let model = TimerModel(clock: { clock.now })
    var alerts = 0
    let module = TimerModule(model: model, automaticallyTick: false, completion: { alerts += 1 })
    module.start()
    #expect(model.setDuration(1))
    #expect(model.begin())
    clock.now = 500
    model.advance()
    #expect(model.phase == .finished)
    #expect(model.remaining == 0)
    #expect(module.isActive)
    #expect(module.isCelebrating)
    #expect(alerts == 1)
    model.advance()
    #expect(!model.begin())
    module.stop()
    module.start()
    #expect(alerts == 1)
    model.reset()
    #expect(!module.isActive)
    #expect(!module.isCelebrating)
    #expect(model.begin())
    clock.now = 502
    model.advance()
    #expect(alerts == 2)
    module.stop()
    #expect(!module.isActive)
    #expect(!module.isCelebrating)
}

@Test @MainActor func stopwatchAccumulatesWithoutCountdownCompletion() {
    let clock = TestTimerClock()
    let model = TimerModel(clock: { clock.now })
    #expect(model.setMode(.stopwatch))
    #expect(model.begin())
    clock.now = 3661
    model.advance()
    model.pause()
    #expect(model.phase == .paused)
    #expect(model.elapsed == 3661)
    #expect(TimerTime.display(model.elapsed) == "1:01:01")
    #expect(!model.setMode(.countdown))
    #expect(!model.setDuration(5))
    clock.now = 5000
    #expect(model.begin())
    clock.now = 5010
    model.advance()
    #expect(model.elapsed == 3671)
    model.reset()
    #expect(model.setMode(.countdown))
}

@Test @MainActor func timerRejectsInvalidDurationsAndFormatsSubseconds() {
    let model = TimerModel()
    for invalid in [0, -1, Double.nan, Double.infinity, TimerModel.maximumDuration + 1] {
        #expect(!model.setDuration(invalid))
    }
    #expect(model.duration == 60)
    #expect(model.setDuration(TimerModel.maximumDuration))
    #expect(TimerTime.display(0.01, countdown: true) == "00:01")
    #expect(TimerTime.display(0.99) == "00:00")
    #expect(TimerTime.display(.nan) == "00:00")
    #expect(TimerTime.compact(86399, countdown: true) == "23:59h")
    #expect(TimerTime.compact(360000, countdown: false) == "100h")
}

@Test @MainActor func timerIgnoresInvalidAndBackwardClockValues() {
    let clock = TestTimerClock()
    clock.now = 10
    let model = TimerModel(clock: { clock.now })
    #expect(model.begin())
    clock.now = 12
    model.advance()
    #expect(model.elapsed == 2)
    clock.now = 11
    model.advance()
    #expect(model.elapsed == 2)
    clock.now = .nan
    model.advance()
    #expect(model.elapsed == 2)
    model.reset()
    #expect(!model.begin())
    #expect(model.phase == .idle)
}

@Test @MainActor func timerTickerStopsAndDoesNotAlertAfterModuleShutdown() async throws {
    let clock = TestTimerClock()
    let model = TimerModel(clock: { clock.now })
    var alerts = 0
    let module = TimerModule(model: model, completion: { alerts += 1 })
    module.start()
    module.start()
    #expect(model.setDuration(1))
    #expect(model.begin())
    clock.now = 2
    try await Task.sleep(for: .milliseconds(220))
    #expect(model.phase == .finished)
    #expect(alerts == 1)
    model.reset()
    #expect(model.begin())
    module.stop()
    module.stop()
    #expect(model.phase == .paused)
    clock.now = 500
    try await Task.sleep(for: .milliseconds(220))
    #expect(model.elapsed == 0)
    #expect(alerts == 1)
}
