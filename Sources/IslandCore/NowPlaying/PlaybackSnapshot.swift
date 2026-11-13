import Foundation

public struct PlaybackSnapshot: Equatable, Sendable {
    public let bundleIdentifier: String
    public let identifier: String
    public let title: String
    public let artist: String
    public let album: String
    public let isPlaying: Bool
    public let duration: TimeInterval?
    public let elapsedTime: TimeInterval?
    public let sampledAt: Date
    public let playbackRate: Double
    public let artworkData: Data?
    public let prohibitsSkip: Bool

    public var identity: String { bundleIdentifier + "\u{1F}" + identifier }

    public init(bundleIdentifier: String, identifier: String, title: String,
                artist: String = "", album: String = "", isPlaying: Bool,
                duration: TimeInterval? = nil, elapsedTime: TimeInterval? = nil,
                sampledAt: Date = Date(), playbackRate: Double = 1,
                artworkData: Data? = nil, prohibitsSkip: Bool = false) {
        self.bundleIdentifier = bundleIdentifier
        self.identifier = identifier
        self.title = title
        self.artist = artist
        self.album = album
        self.isPlaying = isPlaying && (!playbackRate.isFinite || playbackRate > 0)
        self.duration = duration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        self.elapsedTime = elapsedTime.flatMap { $0.isFinite ? max(0, $0) : nil }
        self.sampledAt = sampledAt.timeIntervalSince1970.isFinite ? sampledAt : Date()
        self.playbackRate = playbackRate.isFinite ? max(0, playbackRate) : 1
        self.artworkData = artworkData.flatMap { $0.count <= 4 * 1024 * 1024 ? $0 : nil }
        self.prohibitsSkip = prohibitsSkip
    }

    public func position(at now: Date) -> TimeInterval? {
        guard let elapsedTime else { return nil }
        let age = now.timeIntervalSince(sampledAt)
        let delta = age.isFinite && isPlaying ? max(0, age) * playbackRate : 0
        let position = max(0, elapsedTime + delta)
        return duration.map { min($0, position) } ?? position
    }

    public func progress(at now: Date) -> Double? {
        guard let duration, let position = position(at: now) else { return nil }
        return min(1, max(0, position / duration))
    }
}

public enum MediaCommand: Sendable {
    case previous, togglePlayPause, next
    var adapterID: String {
        switch self { case .previous: "5"; case .togglePlayPause: "2"; case .next: "4" }
    }
    var appleScriptCommand: String {
        switch self { case .previous: "previous track"; case .togglePlayPause: "playpause"; case .next: "next track" }
    }
}
