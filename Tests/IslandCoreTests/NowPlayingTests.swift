import Foundation
@testable import IslandCore
import Testing

@Test func nowPlayingDecodesMicrosArtworkAndTimestamp() throws {
    let data = Data(#"{"type":"data","diff":false,"payload":{"bundleIdentifier":"com.apple.Music","contentItemIdentifier":"track-1","title":"Song","artist":"Artist","playing":true,"playbackRate":1,"durationMicros":200000000,"elapsedTimeMicros":10000000,"timestampEpochMicros":1000000000,"artworkData":"AQID"}}"#.utf8)
    var decoder = NowPlayingDecoder()
    let decoded = try decoder.decode(data)
    let snapshot = try #require(decoded)
    #expect(snapshot.duration == 200)
    #expect(snapshot.elapsedTime == 10)
    #expect(snapshot.sampledAt == Date(timeIntervalSince1970: 1000))
    #expect(snapshot.artworkData == Data([1, 2, 3]))
    #expect(snapshot.identity == "com.apple.Music\u{1F}track-1")
}

@Test func nowPlayingAppliesDiffsAndRemovesNullKeys() throws {
    var decoder = NowPlayingDecoder()
    _ = try decoder.decode(Data(#"{"type":"data","diff":false,"payload":{"bundleIdentifier":"test","title":"Song","artist":"Artist","playing":true,"playbackRate":1,"duration":100,"elapsedTime":10,"artworkData":"AQID"}}"#.utf8))
    let decoded = try decoder.decode(Data(#"{"type":"data","diff":true,"payload":{"playing":false,"artworkData":null,"duration":null}}"#.utf8))
    let snapshot = try #require(decoded)
    #expect(snapshot.title == "Song")
    #expect(!snapshot.isPlaying)
    #expect(snapshot.artworkData == nil)
    #expect(snapshot.duration == nil)
    #expect(try decoder.decode(Data(#"{"type":"data","diff":false,"payload":{}}"#.utf8)) == nil)
}

@Test func idleAndIncompleteMediaAreNormal() throws {
    var decoder = NowPlayingDecoder()
    #expect(try decoder.decode(Data("null".utf8)) == nil)
    #expect(try decoder.decode(Data(#"{"bundleIdentifier":"test","playing":true}"#.utf8)) == nil)
    #expect(try decoder.decode(Data(#"{"bundleIdentifier":"test","title":" ","playing":true}"#.utf8)) == nil)
}

@Test func invalidFramesDoNotMasqueradeAsIdle() {
    var decoder = NowPlayingDecoder()
    #expect(throws: (any Error).self) { try decoder.decode(Data("not json".utf8)) }
    #expect(throws: NowPlayingDataError.self) { try decoder.decode(Data("[]".utf8)) }
    #expect(throws: NowPlayingDataError.self) {
        var fresh = NowPlayingDecoder()
        _ = try fresh.decode(Data(#"{"type":"data","diff":true,"payload":{}}"#.utf8))
    }
}

@Test func positionInterpolatesAndClampsWithoutAdvancingPausedMedia() {
    let time = Date(timeIntervalSince1970: 1000)
    let playing = PlaybackSnapshot(bundleIdentifier: "test", identifier: "1", title: "Song", isPlaying: true,
                                   duration: 100, elapsedTime: 20, sampledAt: time, playbackRate: 2)
    #expect(playing.position(at: time.addingTimeInterval(5)) == 30)
    #expect(playing.progress(at: time.addingTimeInterval(5)) == 0.3)
    #expect(playing.position(at: time.addingTimeInterval(100)) == 100)
    #expect(playing.position(at: time.addingTimeInterval(-100)) == 20)
    let paused = PlaybackSnapshot(bundleIdentifier: "test", identifier: "1", title: "Song", isPlaying: false,
                                  duration: 100, elapsedTime: 20, sampledAt: time, playbackRate: 1)
    #expect(paused.position(at: time.addingTimeInterval(60)) == 20)
}

@Test func zeroRateFreezesAnInconsistentPlayingFlag() throws {
    var decoder = NowPlayingDecoder()
    let decoded = try decoder.decode(Data(#"{"bundleIdentifier":"test","title":"Song","playing":true,"playbackRate":0,"duration":100,"elapsedTime":20}"#.utf8))
    let snapshot = try #require(decoded)
    #expect(!snapshot.isPlaying)
    #expect(snapshot.position(at: snapshot.sampledAt.addingTimeInterval(60)) == 20)
}

@Test func missingOrInvalidTimingDoesNotInventProgress() {
    let unknown = PlaybackSnapshot(bundleIdentifier: "test", identifier: "1", title: "Live", isPlaying: true,
                                   duration: .infinity, elapsedTime: .nan)
    #expect(unknown.position(at: Date()) == nil)
    #expect(unknown.progress(at: Date()) == nil)
    let live = PlaybackSnapshot(bundleIdentifier: "test", identifier: "1", title: "Live", isPlaying: true,
                                duration: 0, elapsedTime: -10, sampledAt: Date(timeIntervalSince1970: 1000))
    #expect(live.position(at: Date(timeIntervalSince1970: 1005)) == 5)
    #expect(live.progress(at: Date()) == nil)
}

@MainActor private final class FakePlaybackSource: NowPlayingSource {
    var onEvent: (@MainActor (NowPlayingSourceEvent) -> Void)?
    var starts = 0
    var stops = 0
    var commands = 0
    var authorizations: [BackupPlayer] = []
    func start() { starts += 1 }
    func stop() { stops += 1 }
    func send(_ command: MediaCommand, expected: PlaybackSnapshot) async throws { commands += 1 }
    func authorize(_ player: BackupPlayer) async { authorizations.append(player) }
}

@MainActor private func coordinatorFixture() -> (NowPlayingCoordinator, FakePlaybackSource, FakePlaybackSource, NowPlayingPreferences) {
    let defaults = UserDefaults(suiteName: "IslandNowPlaying.\(UUID().uuidString)")!
    let preferences = NowPlayingPreferences(defaults: defaults)
    let primary = FakePlaybackSource()
    let backup = FakePlaybackSource()
    return (NowPlayingCoordinator(primary: primary, backup: backup, preferences: preferences), primary, backup, preferences)
}

@Test @MainActor func helperFailureClearsStaleMediaAndStartsBackupOnce() {
    let (coordinator, primary, backup, _) = coordinatorFixture()
    coordinator.start()
    let staleCallback = primary.onEvent
    let track = PlaybackSnapshot(bundleIdentifier: "test", identifier: "1", title: "Song", isPlaying: true)
    primary.onEvent?(.snapshot(track))
    #expect(coordinator.snapshot == track)
    primary.onEvent?(.failure("Helper failed"))
    #expect(coordinator.source == .backup)
    #expect(coordinator.snapshot == nil)
    #expect(backup.starts == 1)
    staleCallback?(.snapshot(track))
    staleCallback?(.failure("Late failure"))
    #expect(coordinator.snapshot == nil)
    #expect(backup.starts == 1)
    backup.onEvent?(.snapshot(track))
    #expect(coordinator.snapshot == track)
    coordinator.stop()
    staleCallback?(.snapshot(track))
    #expect(coordinator.source == .stopped)
    #expect(coordinator.snapshot == nil)
}

@Test @MainActor func noTrackNeverActivatesBackupOrAutomation() async {
    let (coordinator, primary, backup, _) = coordinatorFixture()
    coordinator.start()
    primary.onEvent?(.snapshot(nil))
    #expect(coordinator.source == .automatic)
    #expect(backup.starts == 0)
    coordinator.authorize(.music)
    await Task.yield()
    #expect(backup.authorizations.isEmpty)
    coordinator.stop()
}

@Test @MainActor func backupPermissionsRequireAnExplicitAction() async throws {
    let (coordinator, primary, backup, _) = coordinatorFixture()
    coordinator.start()
    primary.onEvent?(.failure("Unavailable"))
    backup.onEvent?(.permissions([.music]))
    #expect(backup.authorizations.isEmpty)
    coordinator.authorize(.music)
    try await Task.sleep(for: .milliseconds(20))
    #expect(backup.authorizations == [.music])
    coordinator.stop()
}

@Test @MainActor func disabledBackupDoesNotStartAndRetryCanRecoverPrimary() {
    let (coordinator, primary, backup, preferences) = coordinatorFixture()
    preferences.musicBackupEnabled = false
    preferences.spotifyBackupEnabled = false
    coordinator.start()
    primary.onEvent?(.failure("Unavailable"))
    #expect(backup.starts == 0)
    #expect(coordinator.snapshot == nil)
    coordinator.retryAutomatic()
    #expect(coordinator.source == .automatic)
    #expect(primary.starts == 2)
    coordinator.stop()
}

@Test func subprocessDrainsLargeOutputBeforeExit() async throws {
    let result = try await Subprocess.run(executable: URL(fileURLWithPath: "/usr/bin/head"),
                                          arguments: ["-c", "262144", "/dev/zero"])
    #expect(result.status == 0)
    #expect(result.output.count == 262144)
}

@Test func subprocessDeadlineTerminatesAnIdleChild() async {
    await #expect(throws: SubprocessError.self) {
        try await Subprocess.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["30"], timeout: 0.05)
    }
}

@Test func subprocessCancellationTerminatesAnIdleChild() async throws {
    let task = Task { try await Subprocess.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["30"]) }
    try await Task.sleep(for: .milliseconds(20))
    task.cancel()
    await #expect(throws: (any Error).self) { try await task.value }
}
