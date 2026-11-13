# Now Playing (module 2)

## Source decision and local probe

Primary: a separate system Perl process loading MediaRemote Adapter, pinned to
`14eed9389241d06e29f7326c19e9ebc6ec8a5f36`. The framework is private and may stop
working after macOS changes. There is no generic public cross-app Now Playing
reader in MediaPlayer/MusicKit on native macOS.

Probe on 2026-11-14, macOS 27.2.1 (26B131), Apple Silicon:

- Native clang build and ad-hoc framework signature succeeded.
- `get --micros` read a paused Chrome session with title, artist, position,
  timestamp, playback rate, and duration. Empty artwork was tolerated.
- Music was initially stopped, with 751 library tracks. Apple Events started
  its first track, and the adapter returned `com.apple.Music`, playing state,
  title/artist/album, duration, timestamp, and position.
- A seven-second stream received idle/start snapshots, the Music artwork
  (178,420 base64 characters), and a pause update. The helper exited with status
  0 after SIGTERM and produced no stderr errors.
- Music's pause update temporarily reported `playing: true` with rate 0.
  Island freezes progress and its state animation when either the playing flag
  is false or a supplied playback rate is zero.

Build output and real playback metadata are kept in ignored `.cache` directories,
not committed. The synthetic upstream test client is only an explicit diagnostic;
normal startup never publishes fake media to check permissions.

## Source and failure lifecycle

`MediaRemoteSource` owns a bounded process session. Missing resources, launch
errors, malformed frames, unexpected stream termination, or a ten-second initial
response timeout disable the automatic source and start the enabled backup.
Empty/null media is normal and never triggers fallback or Automation consent.
Automatic playback is retried only after a user action or a configuration change;
fatal helpers are not relaunched in a loop.

The subprocess runner drains stdout and stderr independently, bounds output,
uses command deadlines, sends SIGTERM on cancellation, and escalates to SIGKILL
after a short grace period. A small Island-owned constructor in the helper also
watches its original parent PID and exits if Island dies unexpectedly.

Backup polling queries only running enabled players. Automation permission is
checked without prompting first. Missing consent is shown in the expanded island
and Settings with an explanation and a player-specific Allow button. Only that
explicit action requests consent. A denial points to Automation settings and
does not retry the system prompt. Scripts run on one serial background actor
with two-second Apple Event timeouts. Spotify artwork uses HTTPS with a size
limit. Playback commands recheck the player/track before dispatch.

Paused sessions remain visible with a static state indicator. Streams without a
known duration have no fabricated percentage. Artwork may be absent or delayed.
Multiple permitted backups prefer a playing player and otherwise retain the
previous player. Generic automatic commands follow the system-elected source.

## Licensing

The upstream adapter is BSD-3-Clause (Jonas van den Berg, Alexander5015, and
contributors). The ejbills Swift wrapper is also BSD-3-Clause (upstream authors
and ejbills). Both permit public GitHub distribution, including modifications,
provided copyright, license terms, disclaimer, and the no-endorsement condition
are retained. Island uses the upstream source directly and its own Swift client;
the Swift wrapper is audited but not linked or redistributed as code.

The source notices, full adapter LICENSE, wrapper license audit copy, revision,
and attribution are under ThirdParty. Binary distributions include the adapter
license in Island.app/Contents/Resources.
