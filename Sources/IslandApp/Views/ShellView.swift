import IslandCore
import SwiftUI

private struct SurfaceMetricsKey: PreferenceKey {
    static let defaultValue = SurfaceMetrics.zero
    static func reduce(value: inout SurfaceMetrics, nextValue: () -> SurfaceMetrics) { value = nextValue() }
}

private struct AnimatedSurface<Content: View>: View, Animatable {
    nonisolated var metrics: SurfaceMetrics
    let tap: () -> Void
    @ViewBuilder let content: () -> Content

    nonisolated var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(metrics.width, metrics.height),
                             AnimatablePair(metrics.topRadius, metrics.bottomRadius)) }
        set {
            metrics.width = newValue.first.first
            metrics.height = newValue.first.second
            metrics.topRadius = newValue.second.first
            metrics.bottomRadius = newValue.second.second
        }
    }

    var body: some View {
        let shape = IslandShape(topRadius: metrics.topRadius, bottomRadius: metrics.bottomRadius)
        shape.fill(IslandDesign.Colors.background)
            .onTapGesture(perform: tap)
            .overlay(alignment: .top) { content() }
            .frame(width: max(IslandDesign.Spacing.hairline, metrics.width), height: max(IslandDesign.Spacing.hairline, metrics.height))
            .clipShape(shape)
            .islandSurfaceFeedback()
            .preference(key: SurfaceMetricsKey.self, value: metrics)
    }
}

struct ShellView: View {
    @ObservedObject var panel: IslandPanelController
    @ObservedObject var interaction: IslandInteraction
    @ObservedObject var registry: ModuleRegistry
    let openSettings: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let layout = panel.layout {
                AnimatedSurface(metrics: layout.metrics(for: interaction.presentation),
                                tap: { interaction.togglePin() }) {
                    ZStack(alignment: .top) {
                        surfaceContent(layout)
                            .id(interaction.presentation)
                            .transition(.islandContent(reduceMotion: reduceMotion))
                    }
                    .animation(reduceMotion ? .easeOut(duration: IslandDesign.Motion.reducedDuration) : IslandDesign.Motion.content,
                               value: interaction.presentation)
                }
                .frame(width: layout.panelFrame.width, height: layout.panelFrame.height, alignment: .top)
                .animation(IslandDesign.Motion.shell(reduceMotion: reduceMotion),
                           value: interaction.presentation)
                .onPreferenceChange(SurfaceMetricsKey.self) { metrics in
                    Task { @MainActor in panel.updateSurfaceMetrics(metrics) }
                }
            }
        }
        .foregroundStyle(IslandDesign.Colors.primary)
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
    }

    @ViewBuilder private func surfaceContent(_ layout: IslandLayout) -> some View {
        switch interaction.presentation {
        case .collapsed:
            Color.clear.allowsHitTesting(false)
        case .compact:
            HStack(spacing: 0) {
                compactWing(.leading)
                Color.clear.frame(width: (layout.notchRect?.width ?? IslandDesign.Layout.pillWingGap) + IslandDesign.Layout.notchWidthPadding)
                compactWing(.trailing)
            }
            .padding(.horizontal, IslandDesign.Spacing.regular)
            .frame(width: layout.compact.width, height: layout.compact.height)
            .allowsHitTesting(false)
        case .expanded:
            VStack(spacing: IslandDesign.Spacing.small) {
                if let module = registry.activeModule {
                    module.expandedView()
                } else {
                    IslandPlaceholder(symbol: "waveform", title: "Nothing playing",
                                      subtitle: "Your audio will appear here.")
                        .frame(height: IslandDesign.Artwork.expandedSize + IslandDesign.Control.primarySize + IslandDesign.Spacing.wide)
                        .allowsHitTesting(false)
                }
                HStack {
                    Button(interaction.isPinned ? "Unpin" : "Pin", systemImage: interaction.isPinned ? "pin.fill" : "pin") { interaction.togglePin() }
                    Spacer()
                    Button("Settings…", systemImage: "gearshape", action: openSettings)
                }
                .buttonStyle(IslandButtonStyle(.quiet, tint: IslandDesign.Colors.secondary))
                .frame(height: IslandDesign.Control.footerHeight)
            }
            .padding(.horizontal, IslandDesign.Spacing.content)
            .padding(.top, (layout.notchRect?.height ?? IslandDesign.Layout.pillContentTop) + IslandDesign.Spacing.medium)
            .padding(.bottom, IslandDesign.Spacing.medium)
            .frame(width: layout.expanded.width, alignment: .top)
        }
    }

    @ViewBuilder private func compactWing(_ position: CompactPosition) -> some View {
        if let module = registry.activeModule {
            module.compactView(for: position).frame(maxWidth: .infinity)
        } else {
            HStack(spacing: IslandDesign.Spacing.tight) {
                Image(systemName: position == .leading ? "square.dashed" : "circle.dashed")
                Text(position == .leading ? "Preview" : "Compact")
            }
            .font(IslandDesign.Typography.Role.caption.font)
            .frame(maxWidth: .infinity)
        }
    }
}
