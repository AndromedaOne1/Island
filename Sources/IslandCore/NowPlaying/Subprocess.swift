import Darwin
import Foundation

struct SubprocessResult: Sendable { let output: Data; let errorOutput: Data; let status: Int32 }
enum SubprocessError: Error, LocalizedError, Sendable {
    case timedOut, cancelled, tooMuchOutput, launch(String)
    var errorDescription: String? {
        switch self {
        case .timedOut: "The playback helper timed out."
        case .cancelled: "The playback request was cancelled."
        case .tooMuchOutput: "The playback helper returned too much data."
        case .launch(let reason): "The playback helper could not start: \(reason)"
        }
    }
}

/// All mutable state and descriptor reads run on queue. Callbacks carry values.
/// The process retains the session until it exits; finish breaks that ownership.
final class Subprocess: @unchecked Sendable {
    private let queue = DispatchQueue(label: "dev.island.playback.process", qos: .utility)
    private let process = Process()
    private let outputPipe = Pipe()
    private let errorPipe = Pipe()
    private var readers: [DispatchSourceRead] = []
    private var timer: DispatchSourceTimer?
    private var killWork: DispatchWorkItem?
    private var output = Data()
    private var errorOutput = Data()
    private var overrideError: SubprocessError?
    private var finished = false
    private var started = false
    private var streaming = false
    private var onOutput: (@Sendable (Data) -> Void)?
    private var completion: (@Sendable (Result<SubprocessResult, any Error>) -> Void)?

    func start(executable: URL, arguments: [String], timeout: TimeInterval? = nil,
               onOutput: (@Sendable (Data) -> Void)? = nil,
               completion: @escaping @Sendable (Result<SubprocessResult, any Error>) -> Void) {
        queue.async { [self] in
            self.completion = completion
            self.onOutput = onOutput
            streaming = onOutput != nil
            guard overrideError == nil else { finish(status: -1); return }
            process.executableURL = executable
            process.arguments = arguments
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            process.terminationHandler = { [self] ended in
                let status = ended.terminationStatus
                queue.async { [self] in finish(status: status) }
            }
            do {
                try process.run()
                started = true
                try? outputPipe.fileHandleForWriting.close()
                try? errorPipe.fileHandleForWriting.close()
                installReader(outputPipe.fileHandleForReading, isError: false)
                installReader(errorPipe.fileHandleForReading, isError: true)
                if let timeout {
                    let deadline = DispatchSource.makeTimerSource(queue: queue)
                    deadline.schedule(deadline: .now() + max(0.01, timeout))
                    deadline.setEventHandler { [weak self] in self?.requestStop(.timedOut) }
                    timer = deadline
                    deadline.resume()
                }
            } catch {
                overrideError = .launch(error.localizedDescription)
                finish(status: -1)
            }
        }
    }

    func cancel() { queue.async { [self] in requestStop(.cancelled) } }

    static func run(executable: URL, arguments: [String], timeout: TimeInterval = 5) async throws -> SubprocessResult {
        let session = Subprocess()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                session.start(executable: executable, arguments: arguments, timeout: timeout) {
                    continuation.resume(with: $0)
                }
            }
        } onCancel: { session.cancel() }
    }

    private func installReader(_ handle: FileHandle, isError: Bool) {
        let fd = handle.fileDescriptor
        _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)
        let reader = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        reader.setEventHandler { [weak self] in self?.drain(handle, isError: isError) }
        reader.setCancelHandler { try? handle.close() }
        readers.append(reader)
        reader.resume()
    }

    private func drain(_ handle: FileHandle, isError: Bool) {
        var bytes = [UInt8](repeating: 0, count: 16 * 1024)
        while true {
            let count = bytes.withUnsafeMutableBytes { Darwin.read(handle.fileDescriptor, $0.baseAddress!, $0.count) }
            guard count > 0 else {
                if count < 0 && errno == EINTR { continue }
                return
            }
            let data = Data(bytes.prefix(count))
            if isError {
                errorOutput.append(data)
                if errorOutput.count > 64 * 1024 { errorOutput = errorOutput.suffix(64 * 1024) }
            } else if streaming {
                onOutput?(data)
            } else {
                output.append(data)
                if output.count > 8 * 1024 * 1024 { requestStop(.tooMuchOutput); return }
            }
        }
    }

    private func requestStop(_ error: SubprocessError) {
        guard !finished else { return }
        if overrideError == nil { overrideError = error }
        guard started else { return }
        if process.isRunning {
            process.terminate()
            if killWork == nil {
                let work = DispatchWorkItem { [self] in
                    if process.isRunning { Darwin.kill(process.processIdentifier, SIGKILL) }
                }
                killWork = work
                queue.asyncAfter(deadline: .now() + 0.75, execute: work)
            }
        }
    }

    private func finish(status: Int32) {
        guard !finished else { return }
        if started {
            drain(outputPipe.fileHandleForReading, isError: false)
            drain(errorPipe.fileHandleForReading, isError: true)
        }
        finished = true
        timer?.cancel(); timer = nil
        killWork?.cancel(); killWork = nil
        readers.forEach { $0.cancel() }; readers.removeAll()
        if !started {
            try? outputPipe.fileHandleForReading.close()
            try? errorPipe.fileHandleForReading.close()
            try? outputPipe.fileHandleForWriting.close()
            try? errorPipe.fileHandleForWriting.close()
        }
        process.terminationHandler = nil
        let callback = completion
        completion = nil
        onOutput = nil
        if let overrideError { callback?(.failure(overrideError)) }
        else { callback?(.success(SubprocessResult(output: output, errorOutput: errorOutput, status: status))) }
    }
}
