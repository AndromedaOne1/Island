import IslandCore
import SwiftUI

private struct SurfaceMetricsKey: PreferenceKey {
    static let defaultValue = SurfaceMetrics.zero
    static func reduce(value: inout SurfaceMetrics, nextValue: () -> SurfaceMetrics) { value = nextValue() }
}

private struct AnimatedSurface<Content: View>: View, Animatable {
    nonisolated var metrics: SurfaceMetrics
    let topBleed: CGFloat
    let notchDepth: CGFloat
    let notchWidth: CGFloat
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
        let height = max(IslandDesign.Spacing.hairline, metrics.height + topBleed)
        ZStack(alignment: .top) {
            IslandGlassBackground()
            if notchDepth > 0 {
                // A solid cap avoids gradient dithering over the physical camera.
                IslandDesign.Colors.background
                    .frame(height: notchDepth + topBleed)
                    .overlay(alignment: .bottom) {
                        LinearGradient(colors: [IslandDesign.Colors.background, .clear],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: IslandDesign.Glass.notchFadeHeight)
                            .offset(y: IslandDesign.Glass.notchFadeHeight)
                    }
                    .allowsHitTesting(false)
            }
        }
            .overlay(alignment: .top) { content().padding(.top, topBleed) }
            .overlay(alignment: .top) {
                if notchWidth > 0 {
                    // Module glows and transitions must never paint over the camera.
                    IslandDesign.Colors.background
                        .frame(width: notchWidth, height: notchDepth + topBleed)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: max(IslandDesign.Spacing.hairline, metrics.width),
                   height: height)
            .clipShape(shape)
            .contentShape(shape)
            .islandSurfaceFeedback()
            .preference(key: SurfaceMetricsKey.self, value: metrics)
    }
}

struct ShellView: View {
    @ObservedObject var panel: IslandPanelController
    @ObservedObject var interaction: IslandInteraction
    @ObservedObject var registry: ModuleRegistry
    let openSettings: () -> Void
    @Environment(\.islandReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let layout = panel.layout {
                AnimatedSurface(metrics: layout.metrics(for: interaction.presentation),
                                topBleed: layout.mode == .notch ? IslandDesign.Layout.notchTopBleed : 0,
                                notchDepth: layout.notchRect?.height ?? 0,
                                notchWidth: layout.notchRect?.width ?? 0) {
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
            }
            .padding(.horizontal, IslandDesign.Spacing.content)
            .padding(.top, (layout.notchRect?.height ?? IslandDesign.Layout.pillContentTop) + IslandDesign.Spacing.regular)
            .padding(.bottom, IslandDesign.Spacing.regular)
            .frame(width: layout.expanded.width, alignment: .top)
            .overlay(alignment: .top) {
                HStack(spacing: 0) {
                    Color.clear.frame(maxWidth: .infinity).allowsHitTesting(false)
                    Color.clear
                        .frame(width: (layout.notchRect?.width ?? IslandDesign.Layout.pillWingGap) + IslandDesign.Layout.notchWidthPadding)
                        .allowsHitTesting(false)
                    Button(action: openSettings) { Image(systemName: "gearshape") }
                        .help("Island Settings").accessibilityLabel("Island Settings")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(IslandButtonStyle(.quiet, tint: IslandDesign.Colors.tertiary))
                .padding(.horizontal, IslandDesign.Spacing.regular)
                .frame(height: layout.notchRect?.height ?? IslandDesign.Layout.pillHeight)
            }
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
