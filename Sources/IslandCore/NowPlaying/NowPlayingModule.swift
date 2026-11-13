import Combine
import ImageIO
import SwiftUI

@MainActor
public final class NowPlayingModule: IslandModule {
    public let id = "now-playing"
    public let title = "Now Playing"
    public let priority = 100
    public let coordinator: NowPlayingCoordinator
    @Published public private(set) var artwork: CGImage?
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
        artwork = nil; artworkData = nil; artworkIdentity = nil
    }

    private func updateArtwork(_ snapshot: PlaybackSnapshot?) {
        let identity = snapshot?.identity
        if identity != artworkIdentity {
            artworkTask?.cancel(); artworkTask = nil
            artwork = nil; artworkData = nil; artworkIdentity = identity
        }
        guard artworkData != snapshot?.artworkData else { return }
        artworkData = snapshot?.artworkData
        artworkTask?.cancel(); artworkTask = nil
        guard let data = snapshot?.artworkData, let identity else { artwork = nil; return }
        let work = Task.detached(priority: .utility) {
            guard !Task.isCancelled, let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil as CGImage? }
            guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Double,
                  let height = properties[kCGImagePropertyPixelHeight] as? Double,
                  width > 0, height > 0, width * height <= 16_000_000 else { return nil as CGImage? }
            let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                           kCGImageSourceThumbnailMaxPixelSize: 256,
                                           kCGImageSourceShouldCacheImmediately: true]
            return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        }
        artworkTask = Task { [weak self] in
            let decoded = await withTaskCancellationHandler { await work.value } onCancel: { work.cancel() }
            guard !Task.isCancelled, self?.artworkIdentity == identity, self?.artworkData == data else { return }
            self?.artwork = decoded
            self?.artworkTask = nil
        }
    }
}

private struct PlaybackArtwork: View {
    let image: CGImage?
    let size: CGFloat
    var body: some View {
        Group {
            if let image { Image(decorative: image, scale: 1).resizable().scaledToFill() }
            else { Image(systemName: "music.note").font(.system(size: size * 0.4)).frame(maxWidth: .infinity, maxHeight: .infinity).background(.white.opacity(0.12)) }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.16))
        .allowsHitTesting(false)
    }
}

private struct CompactPlaybackView: View {
    @ObservedObject var module: NowPlayingModule
    let position: CompactPosition
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if position == .leading { PlaybackArtwork(image: module.artwork, size: 28) }
        else {
            let playing = module.coordinator.snapshot?.isPlaying == true
            TimelineView(.animation(minimumInterval: 1 / 30, paused: !playing || reduceMotion)) { context in
                HStack(spacing: 3) {
                    ForEach(0..<4) { index in
                        let phase = context.date.timeIntervalSinceReferenceDate * 5 + Double(index) * 1.3
                        Capsule().fill(.white.opacity(0.9))
                            .frame(width: 3, height: playing && !reduceMotion ? 5 + 13 * abs(sin(phase)) : 5)
                    }
                }.frame(width: 28, height: 22)
            }
            .accessibilityLabel(playing ? "Playing" : "Paused")
            .allowsHitTesting(false)
        }
    }
}

private struct ExpandedPlaybackView: View {
    @ObservedObject var module: NowPlayingModule
    var body: some View {
        let coordinator = module.coordinator
        if let snapshot = coordinator.snapshot {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    PlaybackArtwork(image: module.artwork, size: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot.title).font(.system(size: 15, weight: .semibold)).lineLimit(2)
                        Text(snapshot.artist.isEmpty ? "Unknown artist" : snapshot.artist)
                            .font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                    }.frame(maxWidth: .infinity, alignment: .leading).allowsHitTesting(false)
                }
                TimelineView(.animation(minimumInterval: 0.25, paused: !snapshot.isPlaying)) { context in
                    VStack(spacing: 4) {
                        if let progress = snapshot.progress(at: context.date) {
                            ProgressView(value: progress).tint(.white).progressViewStyle(.linear)
                        } else { Capsule().fill(.white.opacity(0.15)).frame(height: 4) }
                        HStack {
                            Text(Self.time(snapshot.position(at: context.date)))
                            Spacer()
                            Text(snapshot.duration.map { Self.time($0) } ?? "Live / unknown duration")
                        }.font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                    }
                }.allowsHitTesting(false)
                HStack(spacing: 28) {
                    Button { coordinator.send(.previous) } label: { Image(systemName: "backward.end.fill") }
                        .disabled(snapshot.prohibitsSkip).accessibilityLabel("Previous track")
                    Button { coordinator.send(.togglePlayPause) } label: {
                        Image(systemName: snapshot.isPlaying ? "pause.fill" : "play.fill").frame(width: 24)
                    }.accessibilityLabel(snapshot.isPlaying ? "Pause" : "Play")
                    Button { coordinator.send(.next) } label: { Image(systemName: "forward.end.fill") }
                        .disabled(snapshot.prohibitsSkip).accessibilityLabel("Next track")
                }.buttonStyle(.plain).font(.system(size: 18)).frame(height: 28)
                    .disabled(coordinator.isCommandInFlight)
                if let error = coordinator.commandError {
                    Text(error).font(.system(size: 10)).foregroundStyle(.orange).lineLimit(2)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Allow player control").font(.headline)
                Text("Island needs Automation access to read the current track and control Music or Spotify when the backup is used.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                HStack {
                    ForEach(coordinator.pendingPermissions) { player in
                        Button("Allow \(player.name)…") { coordinator.authorize(player) }
                    }
                }.buttonStyle(.bordered).controlSize(.small)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private static func time(_ seconds: TimeInterval?) -> String {
        guard let seconds, seconds.isFinite else { return "—:—" }
        let total = Int(min(864_000, max(0, seconds)))
        if total >= 3600 { return String(format: "%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60) }
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
