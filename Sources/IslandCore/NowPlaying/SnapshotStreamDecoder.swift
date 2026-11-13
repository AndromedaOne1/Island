import Foundation

/// Frames and decodes the stream on a serial background actor.
actor SnapshotStreamDecoder {
    private var buffer = Data()
    private var decoder = NowPlayingDecoder()
    func consume(_ data: Data) throws -> [PlaybackSnapshot?] {
        buffer.append(data)
        guard buffer.count <= 8 * 1024 * 1024 else { throw NowPlayingDataError.oversizedPayload }
        var snapshots: [PlaybackSnapshot?] = []
        while let newline = buffer.firstIndex(of: 10) {
            let line = Data(buffer[..<newline])
            buffer.removeSubrange(...newline)
            if !line.isEmpty { snapshots.append(try decoder.decode(line)) }
        }
        return snapshots
    }
    func decodeOne(_ data: Data) throws -> PlaybackSnapshot? {
        var one = NowPlayingDecoder()
        return try one.decode(data)
    }
}
