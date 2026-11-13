import AppKit
import Foundation

@MainActor
public final class AppleEventsSource: NowPlayingSource {
    public var onEvent: (@MainActor (NowPlayingSourceEvent) -> Void)?
    private let preferences: NowPlayingPreferences
    private let client = AppleEventsClient()
    private var pollTask: Task<Void, Never>?
    private var generation = UUID()
    private var preferredPlayer: BackupPlayer?
    private var artworkCache: (url: String, data: Data)?

    public init(preferences: NowPlayingPreferences) { self.preferences = preferences }

    public func start() {
        stop()
        let token = generation
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard self?.generation == token else { return }
                await self?.poll(token: token)
                try? await Task.sleep(for: .milliseconds(900))
            }
        }
    }

    public func stop() {
        generation = UUID()
        pollTask?.cancel(); pollTask = nil
        preferredPlayer = nil
        artworkCache = nil
    }

    public func authorize(_ player: BackupPlayer) async {
        guard preferences.backupPlayers.contains(player), isRunning(player) else { return }
        _ = await client.permission(for: player, ask: true)
    }

    public func send(_ command: MediaCommand, expected: PlaybackSnapshot) async throws {
        guard let player = BackupPlayer.allCases.first(where: { $0.bundleIdentifier == expected.bundleIdentifier }),
              isRunning(player) else { throw PlaybackSourceError("The current player closed.") }
        try await client.send(command, player: player, expected: expected)
    }

    private func isRunning(_ player: BackupPlayer) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == player.bundleIdentifier }
    }

    private func poll(token: UUID) async {
        let players = preferences.backupPlayers.filter(isRunning)
        var snapshots: [(BackupPlayer, PlaybackSnapshot)] = []
        var pending: [BackupPlayer] = []
        var notices: [String] = []
        for player in players {
            do {
                let result = try await client.read(player)
                guard generation == token, !Task.isCancelled else { return }
                switch result {
                case .snapshot(let snapshot): if let snapshot { snapshots.append((player, snapshot)) }
                case .permissionRequired: pending.append(player)
                case .denied: notices.append("Allow \(player.name) control in System Settings → Privacy & Security → Automation.")
                }
            } catch { notices.append("\(player.name): \(error.localizedDescription)") }
        }
        guard generation == token, !Task.isCancelled else { return }
        let chosen = snapshots.first { $0.1.isPlaying && $0.0 == preferredPlayer }
            ?? snapshots.first { $0.1.isPlaying }
            ?? snapshots.first { $0.0 == preferredPlayer }
            ?? snapshots.first
        preferredPlayer = chosen?.0
        var snapshot = chosen?.1
        if let value = snapshot, chosen?.0 == .spotify, let bytes = value.artworkData,
           let urlString = String(data: bytes, encoding: .utf8) {
            let artwork = await spotifyArtwork(urlString)
            guard generation == token, !Task.isCancelled else { return }
            snapshot = PlaybackSnapshot(bundleIdentifier: value.bundleIdentifier, identifier: value.identifier,
                                        title: value.title, artist: value.artist, album: value.album, isPlaying: value.isPlaying,
                                        duration: value.duration, elapsedTime: value.elapsedTime, sampledAt: value.sampledAt,
                                        playbackRate: value.playbackRate, artworkData: artwork)
        }
        onEvent?(.snapshot(snapshot))
        onEvent?(.permissions(pending))
        onEvent?(.notice(notices.isEmpty ? nil : notices.joined(separator: "\n")))
    }

    private func spotifyArtwork(_ urlString: String) async -> Data? {
        if artworkCache?.url == urlString { return artworkCache?.data }
        guard let url = URL(string: urlString), url.scheme == "https" else { return nil }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  response.expectedContentLength <= 4 * 1024 * 1024 else { return nil }
            var data = Data()
            for try await byte in bytes {
                guard data.count < 4 * 1024 * 1024, !Task.isCancelled else { return nil }
                data.append(byte)
            }
            guard !Task.isCancelled else { return nil }
            artworkCache = (urlString, data)
            return data
        } catch { return nil }
    }
}
