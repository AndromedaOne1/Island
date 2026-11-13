import Foundation

public enum BackupPlayer: String, CaseIterable, Sendable, Identifiable {
    case music, spotify
    public var id: String { rawValue }
    public var name: String { self == .music ? "Music" : "Spotify" }
    public var bundleIdentifier: String { self == .music ? "com.apple.Music" : "com.spotify.client" }
}

public enum NowPlayingSourceEvent: Sendable {
    case snapshot(PlaybackSnapshot?)
    case failure(String)
    case permissions([BackupPlayer])
    case notice(String?)
}

@MainActor
public protocol NowPlayingSource: AnyObject {
    var onEvent: (@MainActor (NowPlayingSourceEvent) -> Void)? { get set }
    func start()
    func stop()
    func send(_ command: MediaCommand, expected: PlaybackSnapshot) async throws
    func authorize(_ player: BackupPlayer) async
}

extension NowPlayingSource { public func authorize(_ player: BackupPlayer) async {} }

public struct PlaybackSourceError: Error, LocalizedError, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}
