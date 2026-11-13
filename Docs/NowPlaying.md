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
- Stream and control results are recorded below after integration validation.

Build output and real playback metadata are kept in ignored `.cache` directories,
not committed. The synthetic upstream test client is only an explicit diagnostic;
normal startup never publishes fake media to check permissions.

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
