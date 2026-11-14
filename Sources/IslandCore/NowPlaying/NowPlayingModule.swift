import Combine
import ImageIO
import SwiftUI

private struct ArtworkRendering: Sendable {
    let image: CGImage
    let palette: ArtworkPalette
}

@MainActor
public final class NowPlayingModule: IslandModule {
    public let id = "now-playing"
    public let title = "Now Playing"
    public let priority = 100
    public let coordinator: NowPlayingCoordinator
    @Published public private(set) var artwork: CGImage?
    @Published public private(set) var palette = ArtworkPalette.fallback
    public var isActive: Bool {
        coordinator.source != .stopped && (coordinator.snapshot != nil || !coordinator.pendingPermissions.isEmpty)
    }
    private var subscriptions: Set<AnyCancellable> = []
    private var artworkTask: Task<Void, Never>?
    private var artworkData: Data?
    private var artworkIdentity: String?

    public init(coordinator: NowPlayingCoordinator) {
        self.coordinator = coordinator
        coordinator.objectWillChange.sink { [weak self] in
            Task { @MainActor [weak self] in self?.objectWillChange.send() }
        }.store(in: &subscriptions)
        coordinator.$snapshot.sink { [weak self] snapshot in self?.updateArtwork(snapshot) }
            .store(in: &subscriptions)
    }

    public func compactView(for position: CompactPosition) -> AnyView {
        AnyView(CompactPlaybackView(module: self, position: position))
    }
    public func expandedView() -> AnyView { AnyView(ExpandedPlaybackView(module: self)) }
    public func start() { coordinator.start() }
    public func stop() {
        artworkTask?.cancel(); artworkTask = nil
        coordinator.stop()
        artwork = nil; palette = .fallback; artworkData = nil; artworkIdentity = nil
    }

    private func updateArtwork(_ snapshot: PlaybackSnapshot?) {
        let identity = snapshot?.identity
        if identity != artworkIdentity {
            artworkTask?.cancel(); artworkTask = nil
            artwork = nil; palette = .fallback; artworkData = nil; artworkIdentity = identity
        }
        guard artworkData != snapshot?.artworkData else { return }
        artworkData = snapshot?.artworkData
        artworkTask?.cancel(); artworkTask = nil
        guard let data = snapshot?.artworkData, let identity else { artwork = nil; palette = .fallback; return }
        let work = Task.detached(priority: .utility) {
            guard !Task.isCancelled, let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil as ArtworkRendering? }
            guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Double,
                  let height = properties[kCGImagePropertyPixelHeight] as? Double,
                  width > 0, height > 0, width * height <= 16_000_000 else { return nil as ArtworkRendering? }
            let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                           kCGImageSourceThumbnailMaxPixelSize: IslandDesign.Artwork.thumbnailPixels,
                                           kCGImageSourceShouldCacheImmediately: true]
            guard !Task.isCancelled, let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
            return ArtworkRendering(image: image, palette: ArtworkPalette.sample(image))
        }
        artworkTask = Task { [weak self] in
            let decoded = await withTaskCancellationHandler { await work.value } onCancel: { work.cancel() }
            guard !Task.isCancelled, self?.artworkIdentity == identity, self?.artworkData == data else { return }
            self?.artwork = decoded?.image
            self?.palette = decoded?.palette ?? .fallback
            self?.artworkTask = nil
        }
    }
}

private struct CompactPlaybackView: View {
    @ObservedObject var module: NowPlayingModule
    let position: CompactPosition
    @Environment(\.islandReduceMotion) private var reduceMotion
    var body: some View {
        if position == .leading {
            IslandArtwork(image: module.artwork, size: IslandDesign.Artwork.compactSize)
        } else {
            let playing = module.coordinator.snapshot?.isPlaying == true
            TimelineView(.animation(minimumInterval: IslandDesign.Motion.frameInterval, paused: !playing || reduceMotion)) { context in
                HStack(spacing: IslandDesign.Spacing.micro) {
                    ForEach(0..<IslandDesign.Indicator.bars, id: \.self) { index in
                        let phase = context.date.timeIntervalSinceReferenceDate * IslandDesign.Indicator.frequency
                            + Double(index) * IslandDesign.Indicator.phaseOffset
                        Capsule().fill(playing ? module.palette.color : IslandDesign.Colors.secondary)
                            .frame(width: IslandDesign.Indicator.barWidth,
                                   height: playing && !reduceMotion
                                    ? IslandDesign.Indicator.restingHeight + IslandDesign.Indicator.amplitude * abs(sin(phase))
                                    : IslandDesign.Indicator.restingHeight)
                    }
                }.frame(width: IslandDesign.Indicator.width, height: IslandDesign.Indicator.height)
            }
            .animation(IslandDesign.Motion.content, value: playing)
            .animation(IslandDesign.Motion.content, value: module.palette)
            .accessibilityLabel(playing ? "Playing" : "Paused")
        }
    }
}

private struct ExpandedPlaybackView: View {
    @ObservedObject var module: NowPlayingModule
    @Environment(\.islandReduceMotion) private var reduceMotion
    var body: some View {
        let coordinator = module.coordinator
        if let snapshot = coordinator.snapshot {
            VStack(spacing: IslandDesign.Spacing.regular) {
                HStack(spacing: IslandDesign.Spacing.medium) {
                    IslandArtwork(image: module.artwork, size: IslandDesign.Artwork.expandedSize)
                    VStack(alignment: .leading, spacing: IslandDesign.Spacing.tight) {
                        IslandTitle(snapshot.title)
                        IslandSubtitle(snapshot.artist.isEmpty ? "Unknown artist" : snapshot.artist)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                .id(snapshot.identity)
                .transition(.islandContent(reduceMotion: reduceMotion))
                .allowsHitTesting(false)

                TimelineView(.animation(minimumInterval: IslandDesign.Motion.progressInterval, paused: !snapshot.isPlaying)) { context in
                    IslandProgressBar(value: snapshot.progress(at: context.date),
                                      position: Self.time(snapshot.position(at: context.date)),
                                      duration: snapshot.duration.map { Self.time($0) } ?? "Live / unknown duration",
                                      tint: module.palette.color, isPlaying: snapshot.isPlaying)
                }.allowsHitTesting(false)

                IslandTransportControls(isPlaying: snapshot.isPlaying, isBusy: coordinator.isCommandInFlight,
                                        prohibitsSkip: snapshot.prohibitsSkip, tint: module.palette.color,
                                        previous: { coordinator.send(.previous) },
                                        toggle: { coordinator.send(.togglePlayPause) },
                                        next: { coordinator.send(.next) })
            }
            .overlay(alignment: .bottom) {
                if let error = coordinator.commandError {
                    Text(error).font(IslandDesign.Typography.Role.caption.font)
                        .foregroundStyle(IslandDesign.Colors.warning).lineLimit(1).help(error)
                        .offset(y: IslandDesign.Typography.Role.caption.lineHeight + IslandDesign.Spacing.tight)
                        .transition(.islandContent(reduceMotion: reduceMotion))
                }
            }
            .background {
                RadialGradient(colors: [module.palette.color.opacity(IslandDesign.Artwork.backdropOpacity), .clear],
                               center: .center, startRadius: 0, endRadius: IslandDesign.Artwork.backdropRadius / 2)
                    .frame(width: IslandDesign.Artwork.backdropRadius * IslandDesign.Artwork.backdropAspect, height: IslandDesign.Artwork.backdropRadius)
                    .blur(radius: IslandDesign.Spacing.wide)
                    .offset(y: IslandDesign.Artwork.expandedSize / 2)
                    .allowsHitTesting(false)
            }
            .animation(reduceMotion ? .easeOut(duration: IslandDesign.Motion.reducedDuration) : IslandDesign.Motion.content,
                       value: snapshot.identity)
            .animation(IslandDesign.Motion.content, value: module.palette)
        } else {
            VStack(spacing: IslandDesign.Spacing.regular) {
                IslandPlaceholder(symbol: "lock.open", title: "Allow player control",
                                  subtitle: "Automation access lets Island read tracks and control Music or Spotify when the backup is used.")
                    .allowsHitTesting(false)
                HStack(spacing: IslandDesign.Spacing.small) {
                    ForEach(coordinator.pendingPermissions) { player in
                        Button("Allow \(player.name)…") { coordinator.authorize(player) }
                    }
                }.buttonStyle(IslandButtonStyle())
            }
        }
    }

    private static func time(_ seconds: TimeInterval?) -> String {
        guard let seconds, seconds.isFinite else { return "—:—" }
        let total = Int(min(864_000, max(0, seconds)))
        if total >= 3600 { return String(format: "%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60) }
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
