import CoreFoundation
import Foundation

public enum NowPlayingDataError: Error, LocalizedError, Sendable {
    case invalidPayload, missingFullSnapshot, oversizedPayload
    public var errorDescription: String? { "The playback source returned invalid data." }
}

/// Supports upstream full snapshots, diffs, null deletions, and normal idle data.
public struct NowPlayingDecoder {
    private var payload: [String: Any] = [:]
    private var hasFullSnapshot = false
    public init() {}

    public mutating func decode(_ data: Data, receivedAt: Date = Date()) throws -> PlaybackSnapshot? {
        guard data.count <= 8 * 1024 * 1024 else { throw NowPlayingDataError.oversizedPayload }
        let value = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        if value is NSNull { payload = [:]; hasFullSnapshot = true; return nil }
        guard let object = value as? [String: Any] else { throw NowPlayingDataError.invalidPayload }
        if object["type"] != nil {
            guard object["type"] as? String == "data", let diff = Self.boolean(object["diff"]),
                  let update = object["payload"] as? [String: Any] else { throw NowPlayingDataError.invalidPayload }
            if diff {
                guard hasFullSnapshot else { throw NowPlayingDataError.missingFullSnapshot }
                for (key, value) in update { payload[key] = value is NSNull ? nil : value }
            } else { payload = update; hasFullSnapshot = true }
        } else { payload = object; hasFullSnapshot = true }
        guard !payload.isEmpty else { return nil }
        guard let bundle = payload["bundleIdentifier"] as? String, !bundle.isEmpty,
              let title = payload["title"] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let playing = Self.boolean(payload["playing"]) else { return nil }

        let artist = payload["artist"] as? String ?? ""
        let album = payload["album"] as? String ?? ""
        let identifier = (payload["contentItemIdentifier"] as? String)
            ?? (payload["uniqueIdentifier"] as? String)
            ?? (payload["uniqueIdentifier"] as? NSNumber)?.stringValue
            ?? [title, artist, album].joined(separator: "\u{1E}")
        let timestamp = Self.number(payload["timestampEpochMicros"]).map { $0 / 1_000_000 }
            ?? Self.number(payload["timestamp"])
        let sampledAt = timestamp.map { Date(timeIntervalSince1970: $0) } ?? receivedAt
        let rate = Self.number(payload["playbackRate"]) ?? (playing ? 1 : 0)
        var artwork: Data?
        if let encoded = payload["artworkData"] as? String, encoded.utf8.count <= 6 * 1024 * 1024 {
            artwork = Data(base64Encoded: encoded)
        }
        return PlaybackSnapshot(bundleIdentifier: bundle, identifier: identifier, title: title,
                                artist: artist, album: album, isPlaying: playing,
                                duration: Self.seconds(payload, name: "duration"),
                                elapsedTime: Self.seconds(payload, name: "elapsedTime"), sampledAt: sampledAt,
                                playbackRate: rate, artworkData: artwork,
                                prohibitsSkip: Self.boolean(payload["prohibitsSkip"]) ?? false)
    }

    private static func seconds(_ payload: [String: Any], name: String) -> Double? {
        number(payload[name + "Micros"]).map { $0 / 1_000_000 } ?? number(payload[name])
    }
    private static func number(_ value: Any?) -> Double? {
        guard let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(),
              value.doubleValue.isFinite else { return nil }
        return value.doubleValue
    }
    private static func boolean(_ value: Any?) -> Bool? {
        guard let value = value as? NSNumber, CFGetTypeID(value) == CFBooleanGetTypeID() else { return nil }
        return value.boolValue
    }
}
