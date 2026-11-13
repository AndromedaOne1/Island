# MediaRemote Adapter source snapshot

- Source: https://github.com/ungive/mediaremote-adapter
- Revision: `14eed9389241d06e29f7326c19e9ebc6ec8a5f36` (2026-11-11)
- License: BSD-3-Clause; see LICENSE and the retained per-file notices.
- Authors: Jonas van den Berg, Alexander5015, and contributors.
- Included: unmodified `src`, `include`, and `bin` directories and LICENSE.

Island builds this source locally with Apple's clang toolchain. The framework
is loaded only by a separate system Perl process, never linked into Island.
The test client is built for explicit diagnostics, not packaged or run during
normal application startup. Build output is ignored by Git.

The ejbills Swift wrapper was also audited: BSD-3-Clause, copyright Jonas van
den Berg and contributors and ejbills. Its source and binaries are not used by
Island. The audited license is preserved in ../Licenses.
