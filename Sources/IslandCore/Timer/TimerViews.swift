import SwiftUI

struct TimerRing: View {
    @ObservedObject var module: TimerModule
    let size: CGFloat
    @Environment(\.islandReduceMotion) private var reduceMotion
    private var accent: Color { module.model.mode == .countdown ? IslandDesign.Timer.accent : IslandDesign.Timer.stopwatchAccent }

    var body: some View {
        let model = module.model
        ZStack {
            Circle().stroke(accent.opacity(IslandDesign.Progress.trackOpacity), lineWidth: IslandDesign.Timer.ringWidth)
            Circle().trim(from: 0, to: model.progress)
                .stroke(model.phase == .paused ? IslandDesign.Colors.secondary : accent,
                        style: StrokeStyle(lineWidth: IslandDesign.Timer.ringWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion || model.phase != .running ? nil : .linear(duration: IslandDesign.Timer.tickInterval), value: model.progress)
            Image(systemName: model.phase == .finished ? "checkmark" : model.mode == .countdown ? "timer" : "stopwatch")
                .font(IslandDesign.Typography.Role.label.font).foregroundStyle(accent)
        }.frame(width: size, height: size)
            .scaleEffect(module.isCelebrating && !reduceMotion ? IslandDesign.Timer.celebrationScale : 1)
            .animation(IslandDesign.Motion.press(reduceMotion: reduceMotion), value: module.isCelebrating)
            .accessibilityHidden(true)
    }
}

struct CompactTimerView: View {
    @ObservedObject var module: TimerModule
    let position: CompactPosition
    var body: some View {
        if position == .leading {
            TimerRing(module: module, size: IslandDesign.Timer.compactRingSize)
        } else {
            let model = module.model
            Text(model.phase == .finished ? "Done" : TimerTime.compact(model.mode == .countdown ? model.remaining : model.elapsed, countdown: model.mode == .countdown))
                .font(IslandDesign.Typography.time).monospacedDigit().lineLimit(1)
                .minimumScaleFactor(IslandDesign.Timer.minimumTextScale)
                .foregroundStyle(model.phase == .paused ? IslandDesign.Colors.secondary : IslandDesign.Colors.primary)
                .accessibilityLabel(model.mode == .countdown ? "Timer remaining" : "Stopwatch elapsed")
        }
    }
}

struct ExpandedTimerView: View {
    @ObservedObject var module: TimerModule
    @Environment(\.islandReduceMotion) private var reduceMotion
    @IslandViewState private var custom = false
    @IslandViewState private var minutes = 1
    @IslandViewState private var seconds = 0
    private var accent: Color { module.model.mode == .countdown ? IslandDesign.Timer.accent : IslandDesign.Timer.stopwatchAccent }

    var body: some View {
        let model = module.model
        VStack(spacing: IslandDesign.Spacing.small) {
            Picker("Mode", selection: Binding(get: { model.mode }, set: { _ = model.setMode($0) })) {
                Text("Timer").tag(TimerMode.countdown)
                Text("Stopwatch").tag(TimerMode.stopwatch)
            }.pickerStyle(.segmented).labelsHidden().disabled(model.phase != .idle)
                .frame(height: IslandDesign.Timer.modeHeight)

            HStack(spacing: IslandDesign.Spacing.regular) {
                TimerRing(module: module, size: IslandDesign.Timer.ringSize)
                Text(TimerTime.display(model.mode == .countdown ? model.remaining : model.elapsed, countdown: model.mode == .countdown))
                    .font(IslandDesign.Timer.timeFont).monospacedDigit().lineLimit(1)
                    .minimumScaleFactor(IslandDesign.Timer.minimumTextScale)
                    .foregroundStyle(IslandDesign.Colors.primary)
                Spacer(minLength: 0)
                Text(status).font(IslandDesign.Typography.Role.caption.font)
                    .foregroundStyle(model.phase == .finished ? accent : IslandDesign.Colors.secondary)
            }.frame(height: IslandDesign.Timer.headerHeight)

            Group {
                if model.mode == .countdown && model.phase == .idle {
                    if custom { customEditor }
                    else { presets }
                } else {
                    Text(model.mode == .stopwatch ? "Elapsed time" : "Remaining time")
                        .font(IslandDesign.Typography.Role.caption.font).foregroundStyle(IslandDesign.Colors.tertiary)
                }
            }.frame(height: IslandDesign.Timer.presetHeight)

            HStack(spacing: IslandDesign.Spacing.regular) {
                Button(action: primaryAction) {
                    Label(actionTitle, systemImage: model.phase == .running ? "pause.fill" : "play.fill")
                        .frame(minHeight: IslandDesign.Control.transportSize - 2 * IslandDesign.Spacing.tight)
                }.buttonStyle(IslandButtonStyle(.standard, tint: accent))
                    .disabled(model.phase == .idle && model.mode == .countdown && custom && minutes * 60 + seconds == 0)
                Button { model.reset() } label: {
                    Label(model.phase == .finished ? "Done" : "Reset", systemImage: "arrow.counterclockwise")
                        .frame(minHeight: IslandDesign.Control.transportSize - 2 * IslandDesign.Spacing.tight)
                }.buttonStyle(IslandButtonStyle(.quiet))
                    .disabled(model.phase == .idle)
            }.frame(maxWidth: .infinity).frame(height: IslandDesign.Control.transportSize)
        }
        .background {
            Circle().fill(accent.opacity(module.isCelebrating ? IslandDesign.Timer.glowOpacity : 0))
                .blur(radius: IslandDesign.Spacing.wide).allowsHitTesting(false)
        }
        .animation(reduceMotion ? .easeOut(duration: IslandDesign.Motion.reducedDuration) : IslandDesign.Motion.content, value: module.isCelebrating)
        .onAppear { loadCustomDuration() }
        .onChange(of: minutes) { if minutes == 1440 { seconds = 0 } }
    }

    private var presets: some View {
        HStack(spacing: IslandDesign.Spacing.tight) {
            ForEach([1, 5, 10], id: \.self) { value in
                Button("\(value) min") { _ = module.model.setDuration(Double(value * 60)) }
                    .buttonStyle(IslandButtonStyle(.quiet, tint: module.model.duration == Double(value * 60) ? accent : IslandDesign.Colors.secondary))
            }
            Button("Custom…") { loadCustomDuration(); custom = true }
                .buttonStyle(IslandButtonStyle(.quiet))
        }
    }

    private var customEditor: some View {
        HStack(spacing: IslandDesign.Spacing.small) {
            TimerAdjustment(value: $minutes, range: 0...1440, unit: "m", name: "minutes")
            TimerAdjustment(value: $seconds, range: 0...(minutes == 1440 ? 0 : 59), unit: "s", name: "seconds")
            Button {
                if module.model.setDuration(Double(minutes * 60 + seconds)) { custom = false }
            } label: { Image(systemName: "checkmark") }
                .buttonStyle(IslandButtonStyle(.quiet, tint: accent))
                .disabled(minutes * 60 + seconds == 0).help("Use custom duration")
                .accessibilityLabel("Use custom duration")
        }
    }

    private func loadCustomDuration() {
        minutes = Int(module.model.duration) / 60
        seconds = Int(module.model.duration) % 60
    }

    private var status: String {
        switch module.model.phase {
        case .idle: "Ready"
        case .running: "Running"
        case .paused: "Paused"
        case .finished: "Time’s up"
        }
    }

    private var actionTitle: String {
        switch module.model.phase {
        case .idle: "Start"
        case .running: "Pause"
        case .paused: "Resume"
        case .finished: "Restart"
        }
    }

    private func primaryAction() {
        if module.model.phase == .running { module.model.pause() }
        else {
            if module.model.phase == .idle && module.model.mode == .countdown && custom {
                guard module.model.setDuration(Double(minutes * 60 + seconds)) else { return }
                custom = false
            }
            if module.model.phase == .finished { module.model.reset() }
            _ = module.model.begin()
        }
    }
}

private struct TimerAdjustment: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String
    let name: String
    var body: some View {
        HStack(spacing: IslandDesign.Spacing.tight) {
            Button { value = max(range.lowerBound, value - 1) } label: { Image(systemName: "minus") }
                .disabled(value <= range.lowerBound).buttonRepeatBehavior(.enabled)
                .accessibilityLabel("Decrease \(name)")
            Text("\(value)\(unit)").font(IslandDesign.Typography.time)
                .frame(width: IslandDesign.Timer.stepperLabelWidth)
            Button { value = min(range.upperBound, value + 1) } label: { Image(systemName: "plus") }
                .disabled(value >= range.upperBound).buttonRepeatBehavior(.enabled)
                .accessibilityLabel("Increase \(name)")
        }.buttonStyle(IslandButtonStyle(.quiet))
    }
}
