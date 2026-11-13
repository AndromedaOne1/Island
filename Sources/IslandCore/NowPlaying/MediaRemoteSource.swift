import Foundation

private enum MediaRemoteMessage: Sendable {
    case bytes(Data)
    case completed(Result<SubprocessResult, any Error>)
}

@MainActor
public final class MediaRemoteSource: NowPlayingSource {
    public var onEvent: (@MainActor (NowPlayingSourceEvent) -> Void)?
    private let scriptURL: URL
    private let frameworkURL: URL
    private var session: Subprocess?
    private var handshakeTask: Task<Void, Never>?
    private var readerTask: Task<Void, Never>?
    private var generation = UUID()
    private var hasReceivedSnapshot = false

    public init(scriptURL: URL, frameworkURL: URL) {
        self.scriptURL = scriptURL
        self.frameworkURL = frameworkURL
    }

    public func start() {
        stop()
        let token = generation
        guard FileManager.default.fileExists(atPath: scriptURL.path),
              FileManager.default.fileExists(atPath: frameworkURL.path) else {
            onEvent?(.failure("Automatic playback is unavailable. The bundled helper is missing.")); return
        }
        let process = Subprocess()
        session = process
        let parser = SnapshotStreamDecoder()
        let (stream, continuation) = AsyncStream<MediaRemoteMessage>.makeStream(bufferingPolicy: .bufferingOldest(512))
        continuation.onTermination = { [weak process] _ in process?.cancel() }
        readerTask = Task { [weak self] in
            for await message in stream {
                guard !Task.isCancelled, self?.generation == token else { return }
                switch message {
                case .bytes(let data):
                    do {
                        let snapshots = try await parser.consume(data)
                        guard !Task.isCancelled, self?.generation == token else { return }
                        for snapshot in snapshots {
                            guard !Task.isCancelled, self?.generation == token else { return }
                            self?.hasReceivedSnapshot = true
                            self?.handshakeTask?.cancel(); self?.handshakeTask = nil
                            self?.onEvent?(.snapshot(snapshot))
                        }
                    } catch {
                        guard !Task.isCancelled, self?.generation == token else { return }
                        self?.fail("Automatic playback returned invalid data."); return
                    }
                case .completed(let result):
                    let reason: String
                    switch result {
                    case .success(let output): reason = "Automatic playback disconnected (status \(output.status))."
                    case .failure(let error): reason = error.localizedDescription
                    }
                    self?.fail(reason)
                    return
                }
            }
            guard !Task.isCancelled, self?.generation == token else { return }
            self?.fail("Automatic playback exceeded its update buffer.")
        }
        process.start(executable: URL(fileURLWithPath: "/usr/bin/perl"),
                      arguments: arguments("stream", ["--micros", "--no-diff", "--debounce=100"]),
                      onOutput: { data in
            if case .dropped = continuation.yield(.bytes(data)) { continuation.finish() }
        }, completion: { result in
            continuation.yield(.completed(result))
            continuation.finish()
        })
        handshakeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled, let self, self.generation == token, !self.hasReceivedSnapshot else { return }
            self.fail("Automatic playback did not respond. Using the Music/Spotify backup.")
        }
    }

    public func stop() {
        generation = UUID()
        handshakeTask?.cancel(); handshakeTask = nil
        readerTask?.cancel(); readerTask = nil
        session?.cancel(); session = nil
        hasReceivedSnapshot = false
    }

    public func send(_ command: MediaCommand, expected: PlaybackSnapshot) async throws {
        let token = generation
        guard session != nil else { throw CancellationError() }
        let result = try await runCommand("get", options: ["--micros", "--no-artwork"], token: token)
        guard generation == token, session != nil else { throw CancellationError() }
        guard result.status == 0 else {
            fail("Automatic playback could not read the current player.")
            throw PlaybackSourceError("The current player could not be checked.")
        }
        let parser = SnapshotStreamDecoder()
        let current: PlaybackSnapshot?
        do { current = try await parser.decodeOne(result.output) }
        catch {
            if generation == token { fail("Automatic playback returned invalid data.") }
            throw error
        }
        guard generation == token, session != nil else { throw CancellationError() }
        guard let current, current.identity == expected.identity else {
            throw PlaybackSourceError("The current player or track changed. Try again.")
        }
        let response = try await runCommand("send", options: [command.adapterID], token: token)
        guard token == generation else { throw CancellationError() }
        guard response.status == 0 else { throw PlaybackSourceError("The player did not accept this playback command.") }
    }

    private func runCommand(_ command: String, options: [String], token: UUID) async throws -> SubprocessResult {
        do {
            return try await Subprocess.run(executable: URL(fileURLWithPath: "/usr/bin/perl"),
                                            arguments: arguments(command, options))
        } catch {
            guard generation == token, !Task.isCancelled else { throw CancellationError() }
            fail(error.localizedDescription)
            throw error
        }
    }

    private func arguments(_ command: String, _ options: [String]) -> [String] {
        [scriptURL.path, frameworkURL.path, command] + options
    }

    private func fail(_ reason: String) {
        stop()
        onEvent?(.failure(reason))
    }
}
