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
    private let downloader = RemoteArtworkDownloader()
    private var artworkCache: (url: String, data: Data?, retryAt: Date)?
    private var artworkTask: Task<Void, Never>?
    private var artworkRequestKey: String?
    private var latestSnapshot: PlaybackSnapshot?

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
        artworkTask?.cancel(); artworkTask = nil
        artworkRequestKey = nil
        latestSnapshot = nil
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
        var snapshots: [(BackupPlayer, PlaybackSnapshot, String?)] = []
        var pending: [BackupPlayer] = []
        var notices: [String] = []
        for player in players {
            do {
                let result = try await client.read(player)
                guard generation == token, !Task.isCancelled else { return }
                switch result {
                case .snapshot(let snapshot, let url): if let snapshot { snapshots.append((player, snapshot, url)) }
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
        if let value = snapshot, chosen?.0 == .spotify, let url = chosen?.2 {
            snapshot = value.replacingArtwork(artworkCache?.url == url ? artworkCache?.data : nil)
            loadArtwork(url, identity: value.identity, token: token)
        } else {
            artworkTask?.cancel(); artworkTask = nil; artworkRequestKey = nil
        }
        latestSnapshot = snapshot
        onEvent?(.snapshot(snapshot))
        onEvent?(.permissions(pending))
        onEvent?(.notice(notices.isEmpty ? nil : notices.joined(separator: "\n")))
    }

    private func loadArtwork(_ url: String, identity: String, token: UUID) {
        let key = identity + "\u{1F}" + url
        if artworkRequestKey != key {
            artworkTask?.cancel(); artworkTask = nil
            artworkRequestKey = nil
        }
        guard artworkRequestKey != key,
              artworkCache?.url != url || (artworkCache?.retryAt ?? .distantPast) < Date() else { return }
        artworkTask?.cancel()
        artworkRequestKey = key
        let downloader = downloader
        artworkTask = Task { [weak self] in
            let artwork = await downloader.fetch(url)
            guard !Task.isCancelled, let self, self.generation == token,
                  self.latestSnapshot?.identity == identity, self.artworkRequestKey == key else { return }
            self.artworkCache = (url, artwork, Date().addingTimeInterval(artwork == nil ? 30 : 3600))
            self.latestSnapshot = self.latestSnapshot?.replacingArtwork(artwork)
            self.onEvent?(.snapshot(self.latestSnapshot))
            self.artworkTask = nil
            self.artworkRequestKey = nil
        }
    }
}

private actor RemoteArtworkDownloader {
    func fetch(_ urlString: String) async -> Data? {
        guard let url = URL(string: urlString), url.scheme == "https" else { return nil }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            defer { bytes.task.cancel() }
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  response.url?.scheme == "https",
                  response.expectedContentLength <= 4 * 1024 * 1024 else { return nil }
            var data = Data()
            for try await byte in bytes {
                guard data.count < 4 * 1024 * 1024, !Task.isCancelled else { return nil }
                data.append(byte)
            }
            guard !Task.isCancelled else { return nil }
            return data
        } catch { return nil }
    }
}
