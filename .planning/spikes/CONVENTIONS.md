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

## Tools & Libraries

- `sdef`, `osascript` — built into macOS, no install needed
- `mcp__plugin_context-mode_context-mode__ctx_fetch_and_index` / `ctx_search` — for GitHub/docs
  research (plain `curl`/`WebFetch` on raw GitHub content gets intercepted by context-mode; use
  these instead)
