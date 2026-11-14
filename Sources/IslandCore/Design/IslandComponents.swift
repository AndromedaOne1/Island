import SwiftUI

// Select the public property wrapper explicitly: CLT 27 lacks the new State macro plugin.
typealias IslandViewState<Value> = SwiftUI.State<Value>

public struct IslandFeedback: Equatable, Sendable {
    public var isHovered = false
    public var isPressed = false
    public init(isHovered: Bool = false, isPressed: Bool = false) {
        self.isHovered = isHovered; self.isPressed = isPressed
    }
}

private struct IslandFeedbackKey: EnvironmentKey {
    static let defaultValue = IslandFeedback()
}

private struct IslandReduceMotionKey: EnvironmentKey {
    static let defaultValue: Bool? = nil
}

public extension EnvironmentValues {
    /// Native accessibility policy by default; a local override supports design previews.
    var islandReduceMotion: Bool {
        get { self[IslandReduceMotionKey.self] ?? accessibilityReduceMotion }
        set { self[IslandReduceMotionKey.self] = newValue }
    }
    var islandFeedback: IslandFeedback {
        get { self[IslandFeedbackKey.self] }
        set { self[IslandFeedbackKey.self] = newValue }
    }
}

private struct IslandSurfaceFeedback: ViewModifier {
    @IslandViewState private var hovered = false
    @GestureState private var pressed = false
    func body(content: Content) -> some View {
        content.environment(\.islandFeedback, IslandFeedback(isHovered: hovered, isPressed: pressed))
            .onHover { hovered = $0 }
            .simultaneousGesture(DragGesture(minimumDistance: 0).updating($pressed) { _, value, _ in value = true })
    }
}

private struct IslandContentPhase: ViewModifier, Animatable {
    nonisolated var visibility: Double
    nonisolated var animatableData: Double {
        get { visibility }
        set { visibility = newValue }
    }
    func body(content: Content) -> some View {
        content.opacity(visibility)
            .scaleEffect(IslandDesign.Motion.contentScale + (1 - IslandDesign.Motion.contentScale) * visibility, anchor: .top)
            .blur(radius: IslandDesign.Motion.contentBlur * (1 - visibility))
    }
}

public extension View {
    func islandSurfaceFeedback() -> some View { modifier(IslandSurfaceFeedback()) }
}

public extension AnyTransition {
    static func islandContent(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .modifier(active: IslandContentPhase(visibility: 0), identity: IslandContentPhase(visibility: 1))
    }
}

public struct IslandButtonStyle: ButtonStyle {
    public enum Kind: Sendable { case standard, quiet, transport, primary }
    let kind: Kind
    let tint: Color
    public init(_ kind: Kind = .standard, tint: Color = IslandDesign.Colors.primary) {
        self.kind = kind; self.tint = tint
    }
    public func makeBody(configuration: Configuration) -> some View {
        IslandStyledButton(configuration: configuration, kind: kind, tint: tint)
    }
}

private struct IslandStyledButton: View {
    let configuration: ButtonStyleConfiguration
    let kind: IslandButtonStyle.Kind
    let tint: Color
    @Environment(\.isEnabled) private var enabled
    @Environment(\.islandReduceMotion) private var reduceMotion
    @IslandViewState private var hovered = false
    private var background: Color {
        if configuration.isPressed { return IslandDesign.Colors.pressed }
        if hovered && enabled { return IslandDesign.Colors.hover }
        return kind == .quiet || kind == .transport ? .clear : IslandDesign.Colors.surface
    }
    var body: some View {
        Group {
            if kind == .transport || kind == .primary {
                configuration.label
                    .font(.system(size: kind == .primary ? IslandDesign.Control.primarySymbol : IslandDesign.Control.transportSymbol, weight: .semibold))
                    .frame(width: kind == .primary ? IslandDesign.Control.primarySize : IslandDesign.Control.transportSize,
                           height: kind == .primary ? IslandDesign.Control.primarySize : IslandDesign.Control.transportSize)
            } else {
                configuration.label.font(IslandDesign.Typography.Role.label.font)
                    .padding(.horizontal, IslandDesign.Control.padding)
                    .padding(.vertical, IslandDesign.Spacing.tight)
            }
        }
        .foregroundStyle(tint)
        .background(background, in: Capsule())
        .contentShape(Capsule())
        .opacity(enabled ? 1 : IslandDesign.Colors.disabledOpacity)
        .scaleEffect(configuration.isPressed && !reduceMotion ? IslandDesign.Motion.pressedScale : 1)
        .animation(IslandDesign.Motion.press(reduceMotion: reduceMotion), value: configuration.isPressed)
        .animation(IslandDesign.Motion.hover, value: hovered)
        .onHover { hovered = $0 }
    }
}

public struct IslandTitle: View {
    let text: String
    public init(_ text: String) { self.text = text }
    public var body: some View { IslandMarquee(text, role: .title, color: IslandDesign.Colors.primary) }
}

public struct IslandSubtitle: View {
    let text: String
    public init(_ text: String) { self.text = text }
    public var body: some View { IslandMarquee(text, role: .subtitle, color: IslandDesign.Colors.secondary) }
}

public struct IslandMarquee: View {
    let text: String
    let role: IslandDesign.Typography.Role
    let color: Color
    @Environment(\.islandReduceMotion) private var reduceMotion
    @Environment(\.islandFeedback) private var feedback
    @IslandViewState private var startedAt = Date()
    public init(_ text: String, role: IslandDesign.Typography.Role, color: Color) {
        self.text = text; self.role = role; self.color = color
    }
    private var label: Text { Text(text).tracking(role == .title ? IslandDesign.Typography.titleTracking : 0) }
    private var foreground: Color {
        guard feedback.isHovered else { return color }
        switch role {
        case .title: return IslandDesign.Colors.primaryHover
        case .subtitle: return IslandDesign.Colors.secondaryHover
        default: return color
        }
    }
    public var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let textWidth = (text as NSString).size(withAttributes: [.font: role.appKitFont,
                                                                  .kern: role == .title ? IslandDesign.Typography.titleTracking : 0]).width
            if reduceMotion || textWidth <= width {
                label.lineLimit(1).truncationMode(.tail)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                TimelineView(.animation(minimumInterval: IslandDesign.Motion.frameInterval)) { context in
                    let distance = textWidth + IslandDesign.Marquee.gap
                    let ramp = IslandDesign.Marquee.rampDuration
                    let travel = distance / IslandDesign.Marquee.speed + ramp
                    let period = IslandDesign.Marquee.holdDuration + travel
                    let elapsed = max(0, context.date.timeIntervalSince(startedAt)).truncatingRemainder(dividingBy: period)
                    let moving = max(0, elapsed - IslandDesign.Marquee.holdDuration)
                    let offset: CGFloat = if moving < ramp {
                        IslandDesign.Marquee.speed * moving * moving / (2 * ramp)
                    } else if moving > travel - ramp {
                        distance - IslandDesign.Marquee.speed * (travel - moving) * (travel - moving) / (2 * ramp)
                    } else {
                        IslandDesign.Marquee.speed * (moving - ramp / 2)
                    }
                    HStack(spacing: IslandDesign.Marquee.gap) {
                        label.fixedSize()
                        label.fixedSize().accessibilityHidden(true)
                    }
                    .offset(x: -offset)
                    .frame(width: width, height: role.lineHeight, alignment: .leading)
                    .mask {
                        let fade = min(IslandDesign.Marquee.fadeWidth / max(width, 1), 0.5)
                        LinearGradient(stops: [
                            .init(color: .white.opacity(max(0, 1 - min(offset, distance - offset) / IslandDesign.Marquee.fadeWidth)), location: 0),
                            .init(color: .white, location: fade),
                            .init(color: .white, location: 1 - fade),
                            .init(color: .clear, location: 1)
                        ], startPoint: .leading, endPoint: .trailing)
                    }
                }
            }
        }
        .frame(height: role.lineHeight)
        .font(role.font).foregroundStyle(foreground)
        .opacity(feedback.isPressed ? IslandDesign.Colors.pressedOpacity : 1)
        .scaleEffect(feedback.isPressed && !reduceMotion ? IslandDesign.Motion.surfacePressedScale : 1, anchor: .leading)
        .animation(IslandDesign.Motion.hover, value: feedback.isHovered)
        .animation(IslandDesign.Motion.press(reduceMotion: reduceMotion), value: feedback.isPressed)
        .onChange(of: text) { startedAt = Date() }
        .onAppear { startedAt = Date() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

public struct IslandProgressBar: View {
    let value: Double?
    let position: String
    let duration: String
    let tint: Color
    let isPlaying: Bool
    @Environment(\.islandFeedback) private var feedback
    @Environment(\.islandReduceMotion) private var reduceMotion
    public init(value: Double?, position: String, duration: String, tint: Color, isPlaying: Bool) {
        self.value = value; self.position = position; self.duration = duration; self.tint = tint; self.isPlaying = isPlaying
    }
    public var body: some View {
        VStack(spacing: IslandDesign.Spacing.small) {
            GeometryReader { geometry in
                Capsule().fill(.white.opacity(feedback.isHovered ? IslandDesign.Progress.hoverTrackOpacity : IslandDesign.Progress.trackOpacity))
                if let value, value.isFinite {
                    Capsule().fill(LinearGradient(colors: [tint, IslandDesign.Colors.primary], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geometry.size.width * min(1, max(0, value)))
                        .animation(reduceMotion || !isPlaying ? nil : .linear(duration: IslandDesign.Motion.progressInterval), value: value)
                }
            }.frame(height: IslandDesign.Progress.height)
            HStack {
                Text(position)
                Spacer()
                Text(duration)
            }.font(IslandDesign.Typography.time).foregroundStyle(IslandDesign.Colors.secondary)
        }
        .opacity(feedback.isPressed ? IslandDesign.Colors.pressedOpacity : 1)
        .scaleEffect(feedback.isPressed && !reduceMotion ? IslandDesign.Motion.surfacePressedScale : 1, anchor: .leading)
        .animation(IslandDesign.Motion.hover, value: feedback.isHovered)
        .animation(IslandDesign.Motion.press(reduceMotion: reduceMotion), value: feedback.isPressed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Playback progress")
        .accessibilityValue("\(position) of \(duration)")
    }
}

public struct IslandTransportControls: View {
    let isPlaying: Bool
    let isBusy: Bool
    let prohibitsSkip: Bool
    let tint: Color
    let previous: () -> Void
    let toggle: () -> Void
    let next: () -> Void
    public init(isPlaying: Bool, isBusy: Bool, prohibitsSkip: Bool, tint: Color,
                previous: @escaping () -> Void, toggle: @escaping () -> Void, next: @escaping () -> Void) {
        self.isPlaying = isPlaying; self.isBusy = isBusy; self.prohibitsSkip = prohibitsSkip
        self.tint = tint; self.previous = previous; self.toggle = toggle; self.next = next
    }
    public var body: some View {
        HStack(spacing: IslandDesign.Spacing.large) {
            Button(action: previous) { Image(systemName: "backward.end.fill") }
                .buttonStyle(IslandButtonStyle(.transport)).disabled(prohibitsSkip)
                .accessibilityLabel("Previous track").help("Previous track")
            Button(action: toggle) { Image(systemName: isPlaying ? "pause.fill" : "play.fill") }
                .buttonStyle(IslandButtonStyle(.primary, tint: tint))
                .accessibilityLabel(isPlaying ? "Pause" : "Play").help(isPlaying ? "Pause" : "Play")
            Button(action: next) { Image(systemName: "forward.end.fill") }
                .buttonStyle(IslandButtonStyle(.transport)).disabled(prohibitsSkip)
                .accessibilityLabel("Next track").help("Next track")
        }.disabled(isBusy).frame(maxWidth: .infinity)
    }
}

public struct IslandPlaceholder: View {
    let symbol: String
    let title: String
    let subtitle: String
    @Environment(\.islandFeedback) private var feedback
    @Environment(\.islandReduceMotion) private var reduceMotion
    public init(symbol: String, title: String, subtitle: String) {
        self.symbol = symbol; self.title = title; self.subtitle = subtitle
    }
    public var body: some View {
        VStack(spacing: IslandDesign.Spacing.medium) {
            Image(systemName: symbol).font(.system(size: IslandDesign.Control.placeholderSymbol, weight: .light))
                .foregroundStyle(IslandDesign.Colors.secondary)
                .frame(width: IslandDesign.Control.placeholderSize, height: IslandDesign.Control.placeholderSize)
                .background(feedback.isHovered ? IslandDesign.Colors.hover : IslandDesign.Colors.surface, in: Circle())
                .scaleEffect(feedback.isPressed && !reduceMotion ? IslandDesign.Motion.surfacePressedScale : 1)
            VStack(spacing: IslandDesign.Spacing.tight) {
                Text(title).font(IslandDesign.Typography.Role.title.font).foregroundStyle(IslandDesign.Colors.primary)
                Text(subtitle).font(IslandDesign.Typography.Role.subtitle.font).foregroundStyle(IslandDesign.Colors.secondary)
                    .multilineTextAlignment(.center)
            }
        }.frame(maxWidth: .infinity)
            .animation(IslandDesign.Motion.hover, value: feedback.isHovered)
            .animation(IslandDesign.Motion.press(reduceMotion: reduceMotion), value: feedback.isPressed)
    }
}
