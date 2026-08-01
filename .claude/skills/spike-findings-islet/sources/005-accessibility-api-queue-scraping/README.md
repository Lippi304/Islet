---
spike: 005
name: accessibility-api-queue-scraping
type: standard
validates: "Given Music.app's 'Playing Next' panel or Spotify's Queue view is open on screen, when queried via the macOS Accessibility API (AXUIElement), then the next 5 upcoming track titles/artists are extractable as UI text nodes"
verdict: PARTIAL
related: [001, 002, 003]
tags: [music, spotify, accessibility, phase-74, frontier]
---

# Spike 005: Accessibility API Queue Scraping

## What This Validates

Given Music.app's "Playing Next" panel or Spotify's Queue view is visibly open on screen, when
queried via the macOS Accessibility API (`AXUIElement`), then the next 5 upcoming track
titles/artists are present as readable UI text nodes — a fundamentally different technical avenue
than AppleScript (Spikes 001/002) or the private MediaRemote framework (Spike 003), since it
reads what's rendered on screen rather than asking either app's own data model for a queue object
that doesn't exist there.

## Research

**No static equivalent exists.** Spike 001/002 could rule things out cheaply via `sdef` before
writing any live code — a static dump of an app's scripting dictionary. Accessibility trees have
no analogous static artifact; they only exist once the target app is running with real UI state.
This spike is a live test from the start, unlike its predecessors.

**Spotify is Electron/Chromium, not native AppKit.** Chromium-based apps build their accessibility
tree lazily — full tree construction only activates once an assistive-technology client is
detected querying it (this is a known Chromium behavior, not specific to Spotify). In practice,
any `AXUIElementCopyAttributeValue` call from an AT client is normally sufficient to trigger this
promotion, so this should work without extra flags — but if children come back empty inside
Spotify's window on the first call, that lazy-activation delay (not "no accessibility support at
all") is the first thing to rule out before concluding it's a dead end.

**Requires a new permission not currently in Islet's footprint.** Accessibility access
(`AXIsProcessTrustedWithOptions`) requires explicit user grant in System Settings > Privacy &
Security > Accessibility, per-binary. This spike triggers that prompt itself; the real feature
would need to request and justify it too — worth weighing as a UX cost even if the technical
approach validates.

**Chosen approach:** a standalone SPM CLI (`AXQueueSpike`) that checks trust, then walks the
target app's window accessibility tree (depth-limited, filtering to text-bearing nodes) and
prints every `role` + `title/value/description` it finds, so the investigation can visually scan
for upcoming-track text rather than guessing a specific attribute path in advance.

## How to Run

```bash
cd .planning/spikes/005-accessibility-api-queue-scraping
swift build     # already verified: builds clean
.build/debug/AXQueueSpike com.apple.Music     # or: com.spotify.client
```

Optional third argument sets max tree depth (default 14): `AXQueueSpike com.spotify.client 20`.

**Before running:** open the app's queue/Up Next panel so it's actually rendered on screen —
in Music.app this is usually the "Playing Next" list toggle near the playback controls; in
Spotify it's the "Queue" icon in the bottom-right of the now-playing bar. The exact control
varies by app version — the goal is just to have a visible list of upcoming tracks somewhere in
the window before dumping the tree.

The first run will trigger the macOS Accessibility permission prompt (or silently fail trust
until granted in System Settings) — grant it, then re-run.

## What to Expect

The tool prints an indented tree per window: `[Role] title | value | description` for every
element with non-empty text, and a final count of text-bearing elements found. Scan the output
for the actual upcoming track titles/artists you can see in the app's queue panel — if they
appear as `AXStaticText` (or similar) values in the dump, the approach works; if the queue region
in the tree is empty/collapsed while other UI text (buttons, menus) does show up, that's evidence
of an accessibility-blocked or virtualized list rather than a permission problem.

## Investigation Trail

**1. Confirmed no static analog exists for AX trees** — unlike `sdef`, ruled nothing out for free;
this spike is live-only by nature (see Research).

**2. Built and compiled clean.** Plain SPM executable target, `import ApplicationServices` +
`AppKit`, no external dependencies (system frameworks only). `swift build` succeeds in 5.4s.

**3. Live tree dump against Music.app — real queue data confirmed.** With Music.app's "Playing
Next" panel (localized: "Wiedergabewarteliste") open, the tree contains a genuine, structured
list: an `AXGroup "Wiedergabewarteliste"` holding a `Verlauf` (History) section, the current
track, then an `AutoPlay` / `Ähnliche Titel abspielen` header, followed by a real sequence of
`AXStaticText` `(title, artist — album)` pairs for the algorithmically-suggested upcoming tracks
— e.g. immediately after the AutoPlay header: `Wendy` / `Lil Lano — Wendy - Single`, `Space
Coupe` / `Data Luv — Stars`, `Alien` / `RIN — Nimmerland`, and more. 689 text-bearing elements
were found in total (dominated by the History section, which is much longer than 5 entries — real
usage would need to locate the AutoPlay header and read forward from there, not just grab the
first N static-text pairs).

**4. Live tree dump against Spotify — confirmed empty, twice, with Queue panel open both times.**
First pass returned only 2 generic elements (just the window title) with the Queue sidebar
visibly expanded. User explicitly confirmed the panel was open for both runs, ruling out "wasn't
actually visible" as the explanation.

**5. Ruled out lazy Chromium AX activation as the cause.** Set `AXManualAccessibility` (a
documented Chromium attribute used by tools like Hammerspoon to force full accessibility-tree
construction on Chrome/Electron apps) on Spotify's app-level `AXUIElement` before dumping.
Result: `AXError -25205` (`kAXErrorAttributeUnsupported`) — the attribute isn't even recognized,
not just false. Spotify Desktop is built on CEF (Chromium Embedded Framework), whose
accessibility bridge is opt-in at build time; if Spotify didn't compile/enable it, no client-side
AX call can conjure a tree that the renderer process never constructs. This is a stronger,
better-evidenced negative than "didn't try hard enough" — it's the specific documented workaround
for exactly this class of problem, rejected outright by the app itself.

## Results

**PARTIAL.** The two apps split cleanly:

- **Music.app: VALIDATED.** The visible "Playing Next" panel (History + current track + AutoPlay
  suggestions) is fully readable via `AXUIElement`, with upcoming `(title, artist, album)` triples
  present as plain static text. This is a real, previously-unavailable data source — Spikes
  001-003 found nothing at all; this finds the same list the user can already see on screen.
  **Caveat carried over from Spike 001:** the AutoPlay section is Apple's algorithmic prediction,
  not a committed queue — Spike 001 already proved Apple Music's server-side autoplay engine can
  override this exact prediction once playback actually advances. Reading this list gives "what
  Music.app is currently showing as up next," not a guarantee of "what will play next."
- **Spotify: INVALIDATED.** No accessibility tree content for the Queue panel (or any window
  content) is exposed at all, confirmed across two live tests with the panel open and after
  attempting the documented Chromium full-tree-activation trick, which the app rejected as an
  unsupported attribute. This isn't a permission or timing problem — Spotify's renderer does not
  appear to build an OS-visible accessibility tree for this UI.

**Net implication for NOW-08:** if the feature is scoped to Apple Music only, or built with
per-source data-source availability (real queue-ish data for Music.app via AX, no queue data for
Spotify), this is a genuinely new, previously-unavailable option. A single app-agnostic solution
across both players still does not exist.

## Origin

Standalone SPM package. Independent of Spikes 001-004 technically (new API surface), but
motivated by their shared conclusion: no app's own data model exposes queue contents, so this
tests reading the *rendered UI* instead of asking for structured data.
