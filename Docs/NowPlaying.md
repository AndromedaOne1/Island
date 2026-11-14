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
Launch failures and deadlines in short-lived command helpers also disable it.
An otherwise healthy player rejecting a transport command shows a control error.
Empty/null media is normal and never triggers fallback or Automation consent.
Automatic playback is retried only after a user action or a configuration change;
fatal helpers are not relaunched in a loop.

The subprocess runner drains stdout and stderr independently, bounds output,
uses command deadlines, sends SIGTERM on cancellation, and escalates to SIGKILL
after a short grace period. A small Island-owned constructor in the helper also
watches its original parent PID and exits if Island dies unexpectedly.
Stream framing, JSON/base64 decoding, and ImageIO thumbnails run off the main
actor. Output queues, artwork bytes, and decoded pixel dimensions are bounded.
Cancelled artwork requests also cancel their URLSession task. Source changes
invalidate pending commands, consent tasks, and late artwork deliveries.

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

## Verification and manual testing

The Swift Testing suite, including design geometry coverage, passes 37 tests
in debug and release. It covers
full/diff/null data, microsecond conversion, malformed data, partial/multiple
stream frames, timestamp-based progress, pause and unknown timing, stale callbacks,
stopping during delivery of queued frames, failure-driven fallback, retained diagnostics,
explicit consent, and subprocess output draining, cancellation, and deadlines.
Run `./Scripts/test.sh` or
`./Scripts/test.sh release`; build and test products remain ignored by Git.

A live Swift harness uses the same sources, coordinator, and module as Island.
On this Mac it verified Music metadata, thumbnail decoding, advancing progress,
stable paused progress, and MediaRemote play/pause/next/previous. Killing its own
stream helper activated the real Apple Events backup, which returned Music
metadata without requesting new consent from the already permitted test host.
Backup thumbnail decoding and Apple Events play/pause/next/previous also passed.
Stopping the module left no stream children. Killing the running Island process
also verified that its production helper exited through the parent watchdog.

Both final app configurations build successfully; bundle metadata and ad-hoc
signatures are validated by the build script. The release bundle is relaunched
for the owner's manual check. All build products and live probe metadata are
excluded from commits.

Music's state and elapsed position arrive in separate asynchronous updates.
The pause check waits for those updates to settle before comparing positions.
The backup polls approximately every 0.9 seconds; tests wait for a fresh stable
state before issuing the next toggle.
Next/previous were tested with a playlist queue; starting an isolated track did
not provide a useful next-track test.

The Swift harness does not verify the final app's TCC identity or its Allow button.
Automatic UI inspection timed out, so the compact/expanded appearance and button
hit areas require the owner's visual check. Spotify and live YouTube transport
controls have not been exercised; the earlier adapter probe read Chrome metadata.

After launching the final bundle:

- [ ] Apple Music: play a playlist; check title, artist, artwork, and progress.
- [ ] Compact: artwork appears to the left of the notch and the state indicator
      to the right; hover expands to the player without covering the camera.
- [ ] Pause/start: indicator and progress stop on pause and resume on play.
- [ ] Next/previous: change tracks within a queue and check artwork replacement.
- [ ] Spotify: repeat the same checks with Spotify as the active player.
- [ ] YouTube in the browser: check metadata, progress, and supported commands
      while the source is Automatic.
- [ ] Backup consent: with Music or Spotify running, enable **Use Music/Spotify
      backup**. Check the explanation, click the player-specific **Allow** button,
      and approve Automation. Verify that no prompt appears before the click.
- [ ] If permission is denied, check the Automation Settings link and absence of
      repeated prompts. Retry Automatic after testing the backup.
- [ ] Stop all players or disable Now Playing; the shell stays usable without
      stale media or playback errors.

## Known limits and recovery

- MediaRemote is private. Changes to macOS, framework symbols, its data format,
  permissions, or the system Perl runtime may disable the automatic source.
  Detected failures activate enabled backups once; Island does not crash or
  continuously restart the helper. **Retry Automatic** explicitly tries again.
- A valid empty snapshot cannot always distinguish idle media from a silent
  compatibility failure. Use **Use Music/Spotify backup** if a playing track
  remains absent. Apple Events covers Music and Spotify, not browser playback.
- The system elects one Now Playing application. Generic commands may be
  accepted by the system but ignored by a player without a supported command or
  a next/previous queue. The source can change between the identity check and
  dispatch; metadata, artwork, and the initial pause position can arrive late.
- Artwork is optional; images above 4 MiB or 16 million pixels are discarded.
  Spotify backup artwork needs HTTPS access. Unknown duration is shown without
  a percentage, and the state indicator is an animation, not an audio visualizer.
- Automation belongs to the signed client identity. A rebuild or a different
  installation/signature may require consent again. Ad-hoc signing is suitable
  for this local test; private API use is unsuitable for Mac App Store submission.

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
