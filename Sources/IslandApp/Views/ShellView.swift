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
        shape.fill(.black)
            .onTapGesture(perform: tap)
            .overlay(alignment: .top) { content() }
            .frame(width: max(1, metrics.width), height: max(1, metrics.height))
            .clipShape(shape)
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
                    surfaceContent(layout)
                }
                .frame(width: layout.panelFrame.width, height: layout.panelFrame.height, alignment: .top)
                .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.42, dampingFraction: 0.8),
                           value: interaction.presentation)
                .onPreferenceChange(SurfaceMetricsKey.self) { metrics in
                    Task { @MainActor in panel.updateSurfaceMetrics(metrics) }
                }
            }
        }
        .foregroundStyle(.white)
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
                Color.clear.frame(width: (layout.notchRect?.width ?? 76) + 12)
                compactWing(.trailing)
            }
            .frame(height: layout.compact.height)
            .padding(.horizontal, 12)
            .allowsHitTesting(false)
        case .expanded:
            VStack(spacing: 14) {
                if let module = registry.activeModule {
                    module.expandedView()
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "capsule.fill").font(.system(size: 22))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Island").font(.headline)
                            Text("Core shell").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: interaction.isPinned ? "pin.fill" : "cursorarrow")
                            .foregroundStyle(.secondary)
                    }
                    .allowsHitTesting(false)
                    Text(interaction.isPinned ? "Pinned open. Click the island or outside to collapse."
                         : "Hover to expand. Click the island to keep it open.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .allowsHitTesting(false)
                }
                HStack {
                    Button(interaction.isPinned ? "Unpin" : "Pin", systemImage: "pin") { interaction.togglePin() }
                    Spacer()
                    Button("Settings…", systemImage: "gearshape", action: openSettings)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 24)
            .padding(.top, (layout.notchRect?.height ?? 16) + 14)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    @ViewBuilder private func compactWing(_ position: CompactPosition) -> some View {
        if let module = registry.activeModule {
            module.compactView(for: position).frame(maxWidth: .infinity)
        } else {
            HStack(spacing: 5) {
                Image(systemName: position == .leading ? "square.dashed" : "circle.dashed")
                Text(position == .leading ? "Preview" : "Compact")
            }
            .font(.system(size: 10, weight: .medium))
            .frame(maxWidth: .infinity)
        }
    }
}
