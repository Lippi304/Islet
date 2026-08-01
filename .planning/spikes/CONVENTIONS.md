# Spike Conventions

Patterns and stack choices established across spike sessions. New spikes follow these unless the
question requires otherwise.

## Stack

Islet is a native macOS Swift app (see `project.yml`, no package.json/pyproject/etc.). Spikes
against macOS system integrations use whatever's already on the machine — no new dependencies:

- **AppleScript / JXA** via `osascript`, for scripting other apps (Music, Spotify, etc.)
- **`sdef`** to dump an app's AppleScript dictionary — the fastest way to get a definitive
  yes/no on "does this scripting API support X" before writing any live-test code
- **Bash** for orchestration/inspection scripts saved alongside each spike
- **Standalone SPM executables** (`swift build` / `swift run`, plain `Package.swift`, system
  frameworks only) for spikes that need real Swift/AppKit code — e.g. linking the exact same
  pinned dependency revision Islet uses (`Package.resolved`), or calling `ApplicationServices`
  (Accessibility API). Keeps the spike isolated from the Islet Xcode project while still testing
  the real production dependency, not a mock.
- **`lsof -i -P -n`** to enumerate what ports a running app actually has open — the equivalent of
  `sdef` for local-network/IPC questions where no static API documentation exists.
- **`nc` (netcat) for raw TCP/HTTP probing, not `curl`/`wget`.** This sandbox's context-mode
  tooling intercepts `curl`/`wget` against any URL (including `127.0.0.1`), which is unhelpful
  when the goal is inspecting raw response bytes/framing rather than fetching a page. A bare
  `nc -w N host port` with a manually-written request string bypasses that and gives you the
  literal bytes back.

## Structure

`.planning/spikes/NNN-descriptive-name/` per spike, e.g.:
- `inspect-sdef.sh` — static dictionary/symbol inspection (no side effects, safe to always run first)
- `test-*.applescript` — live experiments, saved as standalone `.applescript` files runnable via `osascript path.applescript`

## Patterns

- **Static check before live test.** Always dump `sdef` (or equivalent static inspection) for an
  app/framework before writing a live-test script. It's non-invasive and often decisive on its
  own — Spike 002 (Spotify) never needed to touch a live app because `sdef` alone proved there
  was nothing to query.
- **Capture and restore live app state.** Any script that manipulates a real running app (Music,
  Spotify, etc.) must read `sound volume` / `shuffle enabled` / `player state` before mutating
  anything, mute audio during the test, and restore all three afterward. See
  `001-apple-music-queue-scripting/test-shuffle-off.applescript`.
- **Private/undocumented API research uses the community's reverse-engineering work, not blind
  symbol-guessing.** System private frameworks on modern macOS live only in the dyld shared
  cache — there's no on-disk binary to `nm`/`otool`. Cross-reference at least one broad
  reverse-engineered header (e.g. `ios-reversed-headers`) against one actively maintained,
  purpose-specific library already solving the same problem (e.g. an existing project dependency)
  before concluding a capability doesn't exist. Don't write dlopen/dlsym probes against
  guessed symbol names with no documented or reverse-engineered candidate — that's fishing, not
  a spike.
- **`ctx_fetch_and_index` + `ctx_search`** for researching external repos/docs — keeps raw page
  bytes out of the conversation, only pulls matched sections back.
- **A local checkout beats reading vendored source from memory.** For an exact-pinned remote SPM
  dependency, the real source is usually already sitting in
  `~/Library/Developer/Xcode/DerivedData/<Project>-*/SourcePackages/checkouts/<package>/` from a
  prior Xcode build — read the actual `.swift` files there to get the real public API signature
  (closures, types, field names) instead of guessing from the wrapper code that consumes it.
- **Screen-reading (Accessibility API) is a genuinely different data source from
  scripting/private-framework APIs, worth testing independently when both are exhausted.** It has
  no static-check equivalent (AX trees only exist at runtime) and carries its own cost (a new
  permission grant), but it can succeed where an app's own data model has nothing to offer — it
  reads what the app renders, not what it's willing to expose programmatically. Chromium/Electron
  apps lazily build their AX tree; try setting `AXManualAccessibility` on the app element to force
  full construction before concluding an Electron-based app has no accessibility support at all —
  but if that documented attribute itself comes back `kAXErrorAttributeUnsupported`, that's strong
  evidence the renderer never implements the AX bridge, not just that it's inactive.
- **A live response (even an error) is not the same as validated.** Finding a real, responsive
  local IPC/RPC surface (Spike 006, port 7768) is a genuine discovery, but decoding an undocumented
  binary protocol with zero reference implementation to check against is a full reverse-engineering
  project, not a spike — the same "don't guess symbol names with no candidate" rule from private
  frameworks applies equally to undocumented local network protocols. Report the finding and stop;
  don't let "something is there" drift into open-ended fishing.

## Tools & Libraries

- `sdef`, `osascript` — built into macOS, no install needed
- `mcp__plugin_context-mode_context-mode__ctx_fetch_and_index` / `ctx_search` — for GitHub/docs
  research (plain `curl`/`WebFetch` on raw GitHub content gets intercepted by context-mode; use
  these instead)
- `swift build` / `swift run` — standalone SPM executables for live Swift spikes; add a
  `.gitignore` with `.build/` immediately (SwiftPM's build directory contains a full git checkout
  of every dependency, which `git add` will otherwise try to add as an embedded repo)
- `ApplicationServices` (`AXUIElement*`, `AXIsProcessTrustedWithOptions`) — macOS Accessibility
  API, system framework, no install needed. Requires user-granted permission per binary.
- `lsof -i -P -n`, `nc` — built into macOS, for local port/IPC enumeration and raw probing
