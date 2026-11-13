import Combine
import Foundation

@MainActor
public final class NowPlayingCoordinator: ObservableObject {
    public enum Source: String { case stopped, automatic, backup }
    @Published public private(set) var snapshot: PlaybackSnapshot?
    @Published public private(set) var source: Source = .stopped
    @Published public private(set) var pendingPermissions: [BackupPlayer] = []
    @Published public private(set) var statusMessage: String?
    @Published public private(set) var primaryFailureMessage: String?
    @Published public private(set) var commandError: String?
    @Published public private(set) var isCommandInFlight = false
    private let primary: any NowPlayingSource
    private let backup: any NowPlayingSource
    private let preferences: NowPlayingPreferences
    private var subscription: AnyCancellable?
    private var configurationTask: Task<Void, Never>?
    private var commandTask: Task<Void, Never>?
    private var authorizationTask: Task<Void, Never>?
    private var generation = UUID()
    private var running = false

    public init(primary: any NowPlayingSource, backup: any NowPlayingSource, preferences: NowPlayingPreferences) {
        self.primary = primary
        self.backup = backup
        self.preferences = preferences
        subscription = preferences.objectWillChange.sink { [weak self] in
            self?.configurationTask?.cancel()
            self?.configurationTask = Task { @MainActor [weak self] in
                await Task.yield()
                guard !Task.isCancelled, let self, self.running else { return }
                self.restart()
            }
        }
    }

    public func start() { running = true; restart() }
    public func stop() { running = false; configurationTask?.cancel(); stopSources() }

    public func retryAutomatic() {
        guard running else { return }
        if preferences.prefersBackup { preferences.prefersBackup = false }
        else { restart() }
    }

    public func send(_ command: MediaCommand) {
        guard running, !isCommandInFlight, let snapshot, source != .stopped else { return }
        let token = generation
        let provider = source == .automatic ? primary : backup
        isCommandInFlight = true
        commandError = nil
        commandTask = Task { [weak self] in
            do { try await provider.send(command, expected: snapshot) }
            catch {
                guard !Task.isCancelled, self?.generation == token else { return }
                self?.commandError = error.localizedDescription
            }
            guard self?.generation == token else { return }
            self?.isCommandInFlight = false
            self?.commandTask = nil
        }
    }

    public func authorize(_ player: BackupPlayer) {
        guard source == .backup, pendingPermissions.contains(player), authorizationTask == nil else { return }
        let token = generation
        let backup = backup
        authorizationTask = Task { [weak self] in
            await backup.authorize(player)
            guard self?.generation == token else { return }
            self?.authorizationTask = nil
        }
    }

    private func restart() {
        stopSources()
        guard running, preferences.isEnabled else { return }
        if preferences.prefersBackup { activateBackup(reason: nil) }
        else {
            source = .automatic
            installCallback(primary, source: .automatic)
            primary.start()
        }
    }

    private func stopSources() {
        generation = UUID()
        primary.onEvent = nil; backup.onEvent = nil
        primary.stop(); backup.stop()
        commandTask?.cancel(); commandTask = nil
        authorizationTask?.cancel(); authorizationTask = nil
        snapshot = nil
        pendingPermissions = []
        statusMessage = nil
        primaryFailureMessage = nil
        commandError = nil
        isCommandInFlight = false
        source = .stopped
    }

    private func activateBackup(reason: String?) {
        generation = UUID()
        primary.onEvent = nil
        primary.stop()
        commandTask?.cancel(); commandTask = nil
        authorizationTask?.cancel(); authorizationTask = nil
        isCommandInFlight = false
        commandError = nil
        pendingPermissions = []
        snapshot = nil
        source = .backup
        primaryFailureMessage = reason
        statusMessage = reason
        guard !preferences.backupPlayers.isEmpty else {
            statusMessage = "Automatic playback is unavailable. Enable a Music or Spotify backup in Settings."; return
        }
        installCallback(backup, source: .backup)
        backup.start()
    }

    private func installCallback(_ provider: any NowPlayingSource, source expectedSource: Source) {
        let token = generation
        provider.onEvent = { [weak self] event in
            guard let self, self.running, token == self.generation, self.source == expectedSource else { return }
            switch event {
            case .snapshot(let next): if self.snapshot != next { self.snapshot = next }
            case .failure(let reason):
                if expectedSource == .automatic { self.activateBackup(reason: reason) }
                else { self.snapshot = nil; self.statusMessage = reason; self.backup.stop() }
            case .permissions(let players): if self.pendingPermissions != players { self.pendingPermissions = players }
            case .notice(let message):
                let next = message ?? self.primaryFailureMessage
                if self.statusMessage != next { self.statusMessage = next }
            }
        }
    }
}
