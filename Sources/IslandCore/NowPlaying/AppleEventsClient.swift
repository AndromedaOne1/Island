import Carbon
import Foundation

enum AppleEventsReadResult: Sendable {
    case snapshot(PlaybackSnapshot?), permissionRequired, denied
}

/// Serial actor isolation keeps NSAppleScript and descriptors off the UI actor.
/// Every Apple Event has a two-second timeout; no descriptor crosses actors.
actor AppleEventsClient {
    private var cachedArtwork: [BackupPlayer: (identity: String, data: Data?, retryAt: Date)] = [:]

    func permission(for player: BackupPlayer, ask: Bool) -> OSStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: player.bundleIdentifier)
        return AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, ask)
    }

    func read(_ player: BackupPlayer) throws -> AppleEventsReadResult {
        switch permission(for: player, ask: false) {
        case noErr: break
        case OSStatus(errAEEventWouldRequireUserConsent): return .permissionRequired
        default: return .denied
        }
        let identityProperty = player == .music ? "persistent ID" : "id"
        let descriptor = try execute("""
            if application id "\(player.bundleIdentifier)" is not running then return missing value
            tell application id "\(player.bundleIdentifier)"
                if player state is stopped then return missing value
                set selectedTrack to current track
                return {name of selectedTrack, artist of selectedTrack, album of selectedTrack, duration of selectedTrack, player position, player state is playing, \(identityProperty) of selectedTrack}
            end tell
            """)
        guard descriptor.descriptorType != typeNull, descriptor.numberOfItems >= 7,
              let title = descriptor.atIndex(1)?.stringValue, !title.isEmpty else { return .snapshot(nil) }
        let artist = descriptor.atIndex(2)?.stringValue ?? ""
        let album = descriptor.atIndex(3)?.stringValue ?? ""
        let duration = descriptor.atIndex(4)?.doubleValue ?? 0
        let elapsed = descriptor.atIndex(5)?.doubleValue ?? 0
        let playing = descriptor.atIndex(6)?.booleanValue ?? false
        let identifier = descriptor.atIndex(7)?.stringValue ?? [title, artist, album].joined(separator: "\u{1E}")
        let sampledAt = Date()
        var art = cachedArtwork[player]?.identity == identifier ? cachedArtwork[player]?.data : nil
        if cachedArtwork[player]?.identity != identifier || (art == nil && (cachedArtwork[player]?.retryAt ?? .distantPast) < sampledAt) {
            art = try? fetchArtwork(player)
            cachedArtwork[player] = (identifier, art, Date().addingTimeInterval(30))
        }
        return .snapshot(PlaybackSnapshot(bundleIdentifier: player.bundleIdentifier, identifier: identifier,
                                          title: title, artist: artist, album: album, isPlaying: playing,
                                          duration: player == .spotify ? duration / 1000 : duration,
                                          elapsedTime: elapsed, sampledAt: sampledAt,
                                          playbackRate: playing ? 1 : 0, artworkData: art))
    }

    func send(_ command: MediaCommand, player: BackupPlayer, expected: PlaybackSnapshot) throws {
        guard permission(for: player, ask: false) == noErr else {
            throw PlaybackSourceError("Allow \(player.name) control in System Settings → Privacy & Security → Automation.")
        }
        // Check identity inside the same script immediately before sending.
        // Values are compared as strings, escaped as AppleScript literals.
        let property = player == .music ? "persistent ID" : "id"
        _ = try execute("""
            if application id "\(player.bundleIdentifier)" is not running then error "The player closed."
            tell application id "\(player.bundleIdentifier)"
                if (\(property) of current track as text) is not \(literal(expected.identifier)) then error "The track changed. Try again."
                \(command.appleScriptCommand)
            end tell
            """)
    }

    private func fetchArtwork(_ player: BackupPlayer) throws -> Data? {
        let expression = player == .music ? "raw data of artwork 1 of current track" : "artwork url of current track"
        let result = try execute("""
            if application id "\(player.bundleIdentifier)" is not running then return missing value
            tell application id "\(player.bundleIdentifier)" to return \(expression)
            """)
        if player == .music {
            let data = result.data
            return data.isEmpty || data.count > 4 * 1024 * 1024 ? nil : data
        }
        // Network artwork is downloaded separately by the provider, with limits.
        return result.stringValue.flatMap { $0.data(using: .utf8) }
    }

    private func execute(_ body: String) throws -> NSAppleEventDescriptor {
        guard let script = NSAppleScript(source: "with timeout of 2 seconds\n\(body)\nend timeout") else {
            throw PlaybackSourceError("The player control script could not be created.")
        }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? 0
            // No current item and an application quitting are normal idle states.
            if [-1728, -600].contains(code) { return NSAppleEventDescriptor.null() }
            throw PlaybackSourceError(error[NSAppleScript.errorMessage] as? String ?? "The player did not respond.")
        }
        return result
    }

    private func literal(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
