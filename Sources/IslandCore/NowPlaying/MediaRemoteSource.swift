import Foundation

@MainActor
public final class MediaRemoteSource: NowPlayingSource {
    public var onEvent: (@MainActor (NowPlayingSourceEvent) -> Void)?
    private let scriptURL: URL
    private let frameworkURL: URL
    private var session: Subprocess?
    private var handshakeTask: Task<Void, Never>?
    private var buffer = Data()
    private var decoder = NowPlayingDecoder()
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
        process.start(executable: URL(fileURLWithPath: "/usr/bin/perl"),
                      arguments: arguments("stream", ["--micros", "--no-diff", "--debounce=100"]),
                      onOutput: { [weak self] data in
            Task { @MainActor [weak self] in
                guard let self, token == self.generation else { return }
                self.consume(data)
            }
        }, completion: { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self, token == self.generation else { return }
                let reason: String
                switch result {
                case .success(let output): reason = "Automatic playback disconnected (status \(output.status))."
                case .failure(let error): reason = error.localizedDescription
                }
                self.fail(reason)
            }
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
        session?.cancel(); session = nil
        buffer.removeAll()
        decoder = NowPlayingDecoder()
        hasReceivedSnapshot = false
    }

    public func send(_ command: MediaCommand, expected: PlaybackSnapshot) async throws {
        let token = generation
        let result = try await Subprocess.run(executable: URL(fileURLWithPath: "/usr/bin/perl"),
                                              arguments: arguments("get", ["--micros", "--no-artwork"]))
        guard generation == token, session != nil else { throw CancellationError() }
        guard result.status == 0 else { throw PlaybackSourceError("The current player could not be checked.") }
        var checkDecoder = NowPlayingDecoder()
        guard let current = try checkDecoder.decode(result.output), current.identity == expected.identity else {
            throw PlaybackSourceError("The current player or track changed. Try again.")
        }
        let response = try await Subprocess.run(executable: URL(fileURLWithPath: "/usr/bin/perl"),
                                                arguments: arguments("send", [command.adapterID]))
        guard token == generation else { throw CancellationError() }
        guard response.status == 0 else { throw PlaybackSourceError("The player did not accept this playback command.") }
    }

    private func arguments(_ command: String, _ options: [String]) -> [String] {
        [scriptURL.path, frameworkURL.path, command] + options
    }

    private func consume(_ data: Data) {
        buffer.append(data)
        guard buffer.count <= 8 * 1024 * 1024 else { fail("Automatic playback returned an oversized update."); return }
        while let newline = buffer.firstIndex(of: 10) {
            let line = Data(buffer[..<newline])
            buffer.removeSubrange(...newline)
            guard !line.isEmpty else { continue }
            do {
                let snapshot = try decoder.decode(line)
                hasReceivedSnapshot = true
                handshakeTask?.cancel(); handshakeTask = nil
                onEvent?(.snapshot(snapshot))
            } catch { fail("Automatic playback returned invalid data."); return }
        }
    }

    private func fail(_ reason: String) {
        stop()
        onEvent?(.failure(reason))
    }
}
