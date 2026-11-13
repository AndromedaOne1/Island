import Combine
import Foundation

@MainActor
public final class NowPlayingPreferences: ObservableObject {
    private let defaults: UserDefaults
    @Published public var isEnabled: Bool { didSet { defaults.set(isEnabled, forKey: "island.nowPlaying.enabled") } }
    @Published public var prefersBackup: Bool { didSet { defaults.set(prefersBackup, forKey: "island.nowPlaying.prefersBackup") } }
    @Published public var musicBackupEnabled: Bool { didSet { defaults.set(musicBackupEnabled, forKey: "island.nowPlaying.musicBackup") } }
    @Published public var spotifyBackupEnabled: Bool { didSet { defaults.set(spotifyBackupEnabled, forKey: "island.nowPlaying.spotifyBackup") } }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.object(forKey: "island.nowPlaying.enabled") as? Bool ?? true
        prefersBackup = defaults.bool(forKey: "island.nowPlaying.prefersBackup")
        musicBackupEnabled = defaults.object(forKey: "island.nowPlaying.musicBackup") as? Bool ?? true
        spotifyBackupEnabled = defaults.object(forKey: "island.nowPlaying.spotifyBackup") as? Bool ?? true
    }
    public var backupPlayers: [BackupPlayer] {
        (musicBackupEnabled ? [.music] : []) + (spotifyBackupEnabled ? [.spotify] : [])
    }
}
