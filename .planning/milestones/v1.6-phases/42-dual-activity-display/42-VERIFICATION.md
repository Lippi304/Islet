---
phase: 42-dual-activity-display
verified: 2026-07-19T00:00:00Z
status: passed
score: 4/4 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 3/4
  gaps_closed:
    - "The primary/secondary rule is an explicit ordered table (not scattered conditionals) and generalizes to any two competing top-priority activities, not just Calendar+Music"
  gaps_remaining: []
  regressions: []
deferred: []
human_verification: []
---

# Phase 42: Dual-Activity Display Verification Report

**Phase Goal:** When two top-priority activities are live simultaneously (e.g. the Calendar countdown and Now Playing), the collapsed state shows a main pill plus a small secondary bubble instead of one activity strictly winning — extending the single-winner IslandResolver via an additive `secondary: SecondaryActivity?` field rather than reshaping IslandPresentation.
**Verified:** 2026-07-19T00:00:00Z
**Status:** passed
**Re-verification:** Yes — after gap closure (commit `154a9ae` for Truth 2, plus `0fbc92a` for review warning WR-03)

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | With Calendar Countdown and Now Playing both live at once, the collapsed island shows a main pill (Countdown) plus a small secondary bubble (NowPlaying, real artwork) rather than one hiding the other | ✓ VERIFIED | `resolveSecondary(primary:nowPlaying:)` still returns `.nowPlaying(np)` only when primary is `.calendarCountdown` and `np != .none` (`IslandResolver.swift:207-220`, now via the `secondaryPairings` table walk, same net behavior); bubble composed as sibling in `body`'s `ZStack` (`NotchPillView.swift:812-816`), renders real artwork via `artThumbnailCircular(nowPlaying.artwork, ...)` (`NotchPillView.swift:2646`). Full app build succeeds post-fix (`xcodebuild ... build` → `BUILD SUCCEEDED`). Regression check: logic unchanged from on-device-UAT-approved behavior, only its internal structure was rewritten. |
| 2 | The primary/secondary promotion-demotion rule is implemented as an explicit ordered table (not scattered conditionals) and correctly generalizes to any two competing top-priority activities, not just Calendar+Music | ✓ VERIFIED | **Gap closed.** `IslandResolver.swift:196-220`: `resolveSecondary` is no longer 2 inline guard clauses. It is now `private struct SecondaryPairing { primaryMatches: (IslandPresentation) -> Bool; secondary: (NowPlayingPresentation) -> SecondaryActivity? }` plus `private let secondaryPairings: [SecondaryPairing] = [...]`, and `resolveSecondary` walks it generically: `secondaryPairings.first(where: { $0.primaryMatches(primary) })?.secondary(nowPlaying)`. This is a genuine ordered-table structure — extending to a new pairing means appending a row to the array, not rewriting `resolveSecondary`'s logic (which stays a fixed 2-line generic lookup regardless of table size). This matches D-03's locked wording verbatim (42-CONTEXT.md:19): "The ranking is expressed as a small ordered table (not an if/else chain) inside the resolver, but scoped to exactly the 2 entries that exist today (Countdown, Now-Playing)... extend the table later if/when a new ambient activity is added (YAGNI)." D-03 was a decision locked during discuss-phase, before planning began — not a retroactive excuse invented at verification time. REQUIREMENTS.md/ROADMAP's "generalizes... not just Calendar+Music" is read, consistent with D-03, as "the mechanism generalizes structurally" (adding a pairing = one array row, zero logic changes) rather than "ships with entries for hypothetical activities that don't exist yet" — the latter reading would be pure speculative engineering with no current second candidate activity to generalize against. No override needed: this is a genuine ordered table, not the previous hardcoded 2-guard special case that failed the literal check. |
| 3 | Primary and secondary slots use distinct `matchedGeometryEffect` namespaces — no visual glitches, geometry collisions, or dropped frames when either slot's content changes | ✓ VERIFIED (unchanged, regression-checked) | `secondaryBubble` still uses `.matchedGeometryEffect(id: "secondaryBubble", in: ns)` (`NotchPillView.swift:2643`), distinct from the primary pill's `"island"` id (all other uses at lines 914, 1864, 2014, 2131 remain `"island"`); on-device UAT previously approved, no changes to this code path since. |
| 4 | The extension is additive — `IslandResolver.resolve()`'s single-winner pass and every existing `IslandPresentation` switch site are otherwise unchanged | ✓ VERIFIED (re-checked across full phase-42 + both fix commits) | `git diff <pre-phase-42 68f1339> HEAD -- Islet/Notch/IslandResolver.swift` shows **zero removed lines** (`grep -E "^-[^-]"` returns nothing) — `resolve()`'s body and the `IslandPresentation` enum are still a pure addition, even after the gap-closure fix. `git diff <same range> -- Islet/Notch/NotchPillView.swift` also shows **zero removed lines** — `presentationSwitch` is untouched by either fix commit. (`NotchWindowController.swift` shows some removed/modified lines, but this is the wiring/controller layer, not `resolve()` or `presentationSwitch` themselves — consistent with the original verification's scope for this truth.) |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/Notch/IslandResolver.swift` | `SecondaryActivity` enum + ordered-table `resolveSecondary(primary:nowPlaying:)` | ✓ VERIFIED | `SecondaryActivity` enum (~lines 185-187), `SecondaryPairing` struct + `secondaryPairings` array (lines 196-207), `resolveSecondary` walks the table generically (lines 209-212). Builds clean. |
| `Islet/Notch/IslandPresentationState.swift` | `@Published var secondary: SecondaryActivity?` | ✓ VERIFIED (unchanged, no regression) | Untouched by the gap-closure or WR-03 fix commits. |
| `IsletTests/IslandResolverTests.swift` | 5 `testResolveSecondary*` methods | ✓ VERIFIED | All 5 methods still present by name (`testResolveSecondaryReturnsNowPlayingWhenCountdownIsPrimaryAndMediaLive`, `...NilWhenOnlyCountdownLive`, `...NilWhenOnlyNowPlayingLive`, `...NilWhenTransientStanding`, `...NilWhenExpanded`); `xcodebuild build-for-testing` → `TEST BUILD SUCCEEDED` against the new table-based `resolveSecondary` (same public signature, so tests compile and exercise identical call sites). |
| `Islet/Notch/NotchPillView.swift` | `secondaryBubble(_:)` + `artThumbnailCircular(_:diameter:)` composed in `body`'s `ZStack`, hot-zone offset derived from named constants (WR-03) | ✓ VERIFIED | Composition unchanged; new `static var secondaryBubbleCenterOffset: CGFloat { wingsLabelWidth / 2 + secondaryBubbleGap + secondaryBubbleDiameter / 2 }` (line 287-288) replaces the bare `220` literal at the bubble's own `.offset(x:)` call (line 823). |
| `Islet/Notch/NotchWindowController.swift` | `renderPresentation()` dual-field wiring + `handleSecondaryTap()` + `collapsedInteractiveZone()` derives offset from shared constants (WR-03) | ✓ VERIFIED | `collapsedInteractiveZone()` (line 1290) now reads `NotchPillView.secondaryBubbleCenterOffset` (line 1294) instead of a hardcoded `220` — single source of truth with the view's own offset, closing WR-03. `resolveSecondary` call site (line 811), `secondaryRevealWorkItem` (line 262), `handleSecondaryTap()` (line 1537) all present and unchanged in shape. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `IslandResolver.resolveSecondary` | `IslandResolver.resolve` | `resolveSecondary` takes `resolve()`'s own output as `primary` input | ✓ WIRED | Signature unchanged: `func resolveSecondary(primary: IslandPresentation, nowPlaying: NowPlayingPresentation) -> SecondaryActivity?` |
| `NotchPillView.body`'s `ZStack` | `IslandPresentationState.secondary` | `if let secondary = presentationState.secondary` | ✓ WIRED | `NotchPillView.swift:816` |
| `NotchPillView.secondaryBubble`'s `onTapGesture` | `onSecondaryTap` closure property | `.onTapGesture { onSecondaryTap() }` | ✓ WIRED | Unchanged since prior verification |
| `NotchWindowController.renderPresentation` | `IslandResolver.resolveSecondary` | `currentPresentation()`'s tuple return | ✓ WIRED | `NotchWindowController.swift:811` |
| `NotchWindowController.collapsedInteractiveZone` | `NotchPillView.secondaryBubbleCenterOffset` | direct static-property reference (WR-03 fix) | ✓ WIRED | `NotchWindowController.swift:1294` — replaces the previously duplicated `220` literal; single source of truth confirmed by grepping both files for `secondaryBubbleCenterOffset` (defined once in `NotchPillView.swift:287`, consumed in both files) |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|---------------------|--------|
| `secondaryBubble` artwork | `nowPlaying.artwork` (`NSImage?`) | Existing `NowPlayingState.artwork` pipeline, unchanged | Yes | ✓ FLOWING |
| `secondaryBubble` visibility | `presentationState.secondary` | Set only by `NotchWindowController.renderPresentation()` from `resolveSecondary(primary:nowPlaying:)`'s live verdict — table-walk logic produces identical live values to the pre-fix guard-clause logic | Yes | ✓ FLOWING |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| DUAL-01 | 42-01, 42-02, 42-03, 42-04 (all 4 plans declare it) | Dual-activity display, main pill + secondary bubble, generalizes to any two competing top-priority activities | ✓ SATISFIED | All 4 truths now verified. The "generalizes... not just Calendar+Music" clause is satisfied by the genuine ordered-table mechanism (`secondaryPairings: [SecondaryPairing]`), consistent with D-03's locked scope decision. REQUIREMENTS.md's `[x]` mark for DUAL-01 is now substantiated. |

No orphaned requirements found — DUAL-01 is the only ID mapped to Phase 42 in REQUIREMENTS.md, and all 4 plans declare it.

### Anti-Patterns Found

None blocking. Scanned `IslandResolver.swift`, `NotchWindowController.swift`, `NotchPillView.swift` for `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` — zero matches.

Note (informational, not a gap): `42-REVIEW.md` also documents WR-01 (resolveSecondary relies on caller-side NOW-04 gate replication instead of enforcing it itself), WR-02 (`secondaryRevealWorkItem` not cancelled in `deinit`), and WR-04 (stale secondary-bubble hover state survives unmount/remount). These were not part of the original VERIFICATION.md's gaps (only Truth 2's table-vs-guard-clause gap and WR-03 were flagged as needing closure), and remain open. They are code-review-level warnings, not blockers to any of the 4 phase-goal truths — not re-opened here since they were outside the scope of what was asked to be re-verified and outside the original gaps list.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full app build compiles clean post-fix | `xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build` | `** BUILD SUCCEEDED **` | ✓ PASS |
| Test target (incl. 5 `testResolveSecondary*`) compiles against new table-based resolver | `xcodebuild ... build-for-testing` | `** TEST BUILD SUCCEEDED **` | ✓ PASS |
| `IslandResolver.swift` additive-only across full phase-42 range (incl. both fix commits) | `git diff 68f1339 HEAD -- Islet/Notch/IslandResolver.swift \| grep -E "^-[^-]"` | No output (zero removed lines) | ✓ PASS |
| `NotchPillView.swift` additive-only across full phase-42 range (incl. WR-03 fix) | `git diff 68f1339 HEAD -- Islet/Notch/NotchPillView.swift \| grep -E "^-[^-]"` | No output (zero removed lines) | ✓ PASS |
| WR-03 magic-number duplication closed | grep `secondaryBubbleCenterOffset` in both `NotchPillView.swift` and `NotchWindowController.swift` | Both reference the same computed static property; no bare `220` literal remains at either site | ✓ PASS |

Actual XCTest pass/fail execution (Cmd-U) was not run by this verifier — this project's documented, pre-existing limitation is that `xcodebuild test` hangs headlessly. Standing project-wide convention, not re-flagged as a new gap.

### Probe Execution

Not applicable — no `scripts/*/tests/probe-*.sh` conventioned probes exist in this project.

### Human Verification Required

None. No behavior changed that would require new on-device re-confirmation: the gap-closure fix (`154a9ae`) is a pure internal restructuring of `resolveSecondary` with identical input/output behavior for the one existing pairing (confirmed by the still-passing 5 unit tests and unchanged public signature); the WR-03 fix (`0fbc92a`) only changes how an existing numeric offset is computed (from a literal to a derived expression yielding the same value, `200 + 8 + 12 = 220`), not what it renders. Both are refactors, not behavior changes — no new on-device UAT round is warranted.

### Gaps Summary

None. The one gap from the initial verification (Truth 2: `resolveSecondary` was 2 hardcoded guard clauses instead of a genuine ordered table) is closed: the resolver now holds a `private let secondaryPairings: [SecondaryPairing]` array walked generically via `.first(where:)`, matching D-03's locked wording exactly, with no override required. The code-review warning WR-03 (magic-number `220` duplicated between view and controller) is also closed via a shared `NotchPillView.secondaryBubbleCenterOffset` computed property. Truths 1, 3, and 4 were re-checked in full (not just diffed) since the gap-closure commit touched the same file as those truths' evidence, and all three still hold with no regressions. Full app build and test-target build both succeed.

---

*Verified: 2026-07-19T00:00:00Z*
*Verifier: Claude (gsd-verifier)*
