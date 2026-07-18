---
phase: 36-cosmetic-restyles-signature-animation
verified: 2026-07-16T23:15:00Z
status: human_needed
score: 4/4 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Tap directly on the 'Charging'/'Connected' wing label text (not the icon or battery indicator) while the collapsed wing is showing"
    expected: "The tap registers and expands the island, same as tapping the icon or battery flank"
    why_human: "Code review (36-REVIEW.md WR-02) found `NotchWindowController.handlePointer(at:)` still gates click-through on the original ~99pt-half-width `hotZone` (set once in `positionAndShow`, never widened for the wings), while this phase's `wingsLabelWidth` (400pt / 200pt half-width) renders the new label text up to ~200pt from center — well outside that hot-zone. This is a live/dead click-through question that only a real tap on real hardware can answer; grep/build cannot simulate `NSEvent` hit-testing against the actual panel frame."
---

# Phase 36: Cosmetic Restyles & Signature Animation Verification Report

**Phase Goal:** Bluetooth/AirPods and Charging activities are restyled to the Droppy-pill look, the Now Playing equalizer bars get a new visual design, and the onboarding flow's first page gains a static rainbow-gradient signature-style heading — all pure view-layer changes with zero resolver, monitor, or data changes, proving the new visual language renders correctly inside Phase 35's material.
**Verified:** 2026-07-16T23:15:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth (ROADMAP Success Criteria) | Status | Evidence |
|---|---|---|---|
| 1 | Bluetooth/AirPods device-connected activity visually matches the Droppy-pill restyle; `DeviceCoordinator`/`BluetoothMonitor` unchanged | ✓ VERIFIED | `NotchPillView.swift:2113-2137` — left-wing `HStack(spacing:4)` with device glyph + conditional `Text("Connected")` (only `if isConnected`); `deviceTrailing` (`:2148-2159`) is now the exact 3-way branch: `BatteryIndicator` (battery known) / `Circle().strokeBorder(Color.green, lineWidth: 1.5)` (connected, no battery) / dimmed `xmark` (disconnected). `git diff --stat` for this phase touches zero files matching `DeviceCoordinator`/`BluetoothMonitor`. |
| 2 | Charging activity visually matches the Droppy-pill restyle; existing IOKit power monitor unchanged | ✓ VERIFIED (see note) | `NotchPillView.swift:1972-1995` — left-wing `HStack(spacing:4)` with bolt icon + conditional `Text("Charging")` (only `if isCharging`); right-wing `BatteryIndicator(level: percent, accent: chargingAccent)` byte-identical to pre-phase. **Note:** `PowerActivity.swift`'s pure `powerActivity(from:)` classification function *was* changed (commit `bf99ad0`, `isCharged`-keyed instead of `isCharging`-keyed) — a real, user-approved root-cause bug fix (Optimized Battery Charging keeps the raw IOKit flag false for an entire AC session) needed to make the "Charging" label ever actually appear on real hardware. `PowerSourceMonitor.swift` (the actual IOKit polling/monitor code) is untouched — only the downstream pure-function interpretation of already-read fields changed. This is a narrow, documented, tested (`PowerActivityTests.swift` updated) deviation from the phase's literal "zero monitor changes" wording, not a scope violation of `DeviceCoordinator`/`BluetoothMonitor`/IOKit polling itself. |
| 3 | Now Playing equalizer bars render the new visual design with no change to underlying playback data/monitor | ✓ VERIFIED | `NotchPillView.swift:2440-2465` — `EqualizerBars` rewritten: 5 bars, `Capsule().fill(tint).frame(width: 1, ...)`, `HStack(spacing: 4)`, fixed `.white` default (both call sites at `:2061`/`:2280` dropped `tint: nowPlayingAccent`), `targetHeight(bar:bucket:)` Hasher-driven reroll mapped to `4...14`, `.animation(.spring(response: 0.25, dampingFraction: 0.7), value: bucket)`. `TimelineView(.animation(paused: !isPlaying))` idle-CPU gate (D-08) preserved verbatim — paused bars render flat `4`. No `NowPlayingState`/MediaRemote-adapter files touched. |
| 4 | (D-14 pivot) Onboarding first page shows a static rainbow-gradient signature-style script heading replacing "Welcome to Islet"/"Meet Islet" plain text, scoped to that one page | ✓ VERIFIED | `SignatureHeading.swift` (full file) — `HStack(spacing: 8)` of two `Text` views, "Meet" with `LinearGradient([.blue, .purple, .pink])`, "Islet" with `LinearGradient([.orange, .yellow, .green])`, both in Dancing Script Bold (28pt) via `loadSignatureFont`. No `TimelineView`, no `Canvas`, no `.trim()`, no per-frame clock — matches the D-14-pivoted `36-UI-SPEC.md` "Signature Heading Contract" exactly (verified line-by-line against the spec table). `onboardingWelcomeStep` (`NotchPillView.swift:1503-1513`) calls `SignatureHeading()` in place of the old text; body subtext line is byte-identical (D-13, confirmed unchanged). |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `Islet/Notch/NotchPillView.swift` | HUD-01/HUD-02 wing restyle + EQ-01 bars rewrite + ONBOARD-04 wiring | ✓ VERIFIED | All three restyles present, substantive, wired (see truths 1-4 above). Build succeeds. |
| `Islet/Notch/SignatureHeading.swift` | Static two-word gradient heading (post-D-14-pivot) | ✓ VERIFIED | Rewritten from the Plan 36-03/36-04-original stroke-reveal contract to the final static design; `loadSignatureFont` (Plan 36-03's font loader) reused as-is. Old `glyphPaths`/`totalWidth`/animation state removed entirely — no dead code left behind from the pivot. |
| `Islet/Fonts/DancingScript-Variable.ttf` + `DancingScript-OFL.txt` | OFL-licensed font bundled, registers at runtime | ✓ VERIFIED | `file` confirms genuine TrueType binary (133,636 bytes); `OFL.txt` contains "SIL OPEN FONT LICENSE"; wired into `project.pbxproj` Resources build phase (confirmed by 36-REVIEW.md and successful build). `SignatureHeadingTests.testLoadSignatureFontResolvesToDancingScriptFamily` exercises the actual runtime registration + resolution path. |
| `Islet/SettingsView.swift` | Skiper UI attribution row (Registry Safety gate) | ✓ VERIFIED | `Section("Credits") { Text("Equalizer bar animation inspired by Skiper UI (skiper25.com)") }` present verbatim, matching the locked UI-SPEC string exactly. |
| `IsletTests/EqualizerBarsTests.swift` | Tests against `targetHeight(bar:bucket:)` (range + determinism) | ✓ VERIFIED | Old `makeProfiles()` tests fully replaced; new tests assert `4.0...14.0` range across bar 0-4 × bucket 0-49, and determinism for a repeated call. |
| `IsletTests/SignatureHeadingTests.swift` | Sanity test on the post-pivot contract | ✓ VERIFIED | Rewritten (correctly) to test `loadSignatureFont` family resolution only — the old glyph-extraction assertions were removed because `glyphPaths`/`totalWidth` are no longer used by the shipped view; test scope tracks the pivot instead of testing dead code. |
| `IsletTests/PowerActivityTests.swift` | Reflects the `isCharged`-keyed classification fix | ✓ VERIFIED | `testOnACNotChargedMapsToCharging` added; existing tests updated to pass explicit `isCharged` values. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `wings(for:)` HStack | `isCharging` conditional `Text("Charging")` | left-wing `HStack(spacing: 4)` | ✓ WIRED | Confirmed at `NotchPillView.swift:1987` — gated by `if isCharging`. |
| `deviceTrailing(isConnected:battery:)` | `Circle().strokeBorder(Color.green` | `isConnected && battery == nil` branch | ✓ WIRED | Confirmed at `:2156` — old `checkmark`/`xmark` ternary fully removed, replaced by 3-way `if/else if/else`. |
| `EqualizerBars.body` | `EqualizerBars.targetHeight(bar:bucket:)` | `TimelineView(.animation(paused: !isPlaying))` computing `bucket = Int(t / 0.1)` | ✓ WIRED | Confirmed at `:2456-2461`; `.animation(value: bucket)` applied per bar. |
| `IsletTests/EqualizerBarsTests.swift` | `EqualizerBars.targetHeight` | `@testable import Islet` | ✓ WIRED | Both new tests call `EqualizerBars.targetHeight` directly. |
| `onboardingWelcomeStep` | `SignatureHeading()` | direct view call, replacing `Text("Meet Islet")` | ✓ WIRED | Confirmed at `NotchPillView.swift:1508`; `grep -c 'Text("Meet Islet")'` returns 0 (fully replaced), `grep -c 'SignatureHeading()'` returns 1. |

### Data-Flow Trace (Level 4)

Not applicable in the traditional sense — this phase has no server/DB data source. The relevant "data flow" is: (a) `isCharging`/`isConnected`/`battery` booleans/values flowing from already-existing `ChargingActivity`/`DeviceActivity` enums into the restyled views (unchanged plumbing, only the render branch changed) — traced and confirmed live, not hardcoded; (b) `EqualizerBars.targetHeight`'s synthetic (intentionally non-audio-driven, per D-06 scope guard) pseudo-random values — confirmed by design, not a hollow-data defect; (c) `SignatureHeading`'s static literal text/colors — intentionally static per the D-14 pivot, not a data-flow concern.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Full project builds clean (Debug, arm64 Mac destination) | `xcodebuild build -scheme Islet -destination 'platform=macOS'` | `** BUILD SUCCEEDED **` | ✓ PASS |
| All commits referenced in the four SUMMARY.md files exist in git history | `git cat-file -e <hash>` for all 19 referenced hashes (7d56c42, ea661dc, 32ce3d7, 8fcf7fd, 3871ba4, bf99ad0, 77ecd18, 49133c2, 978d464, c07c677, 746d78b, 1d49c77, a6852e2, b3b9f36, b334c37, be4bdbf, 981f20c, a58fc64, e3398d2) | All 19 FOUND | ✓ PASS |
| Font asset is a genuine TrueType binary with OFL license text present | `file Islet/Fonts/DancingScript-Variable.ttf`; `grep -c "SIL OPEN FONT LICENSE" Islet/Fonts/DancingScript-OFL.txt` | "TrueType Font data..."; returns 1 | ✓ PASS |
| No debt markers (TBD/FIXME/XXX) in any file this phase modified | `grep -n -E "TBD\|FIXME\|XXX"` across all 8 touched Swift files | No matches in any file | ✓ PASS |

### Probe Execution

Step 7c: SKIPPED — no `scripts/*/tests/probe-*.sh` files exist in this repository and neither the plans, summaries, nor verification criteria for this phase reference probe-based verification. `xcodebuild test` is documented project-wide as hanging headless (this project's own prior precedent, `xcodebuild-test-headless-hang` memory note) — Cmd-U in Xcode is the correct test-runner path, which is a human/GUI action, not a scriptable probe.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| HUD-01 | 36-01 | Bluetooth/AirPods device-connected activity restyled to Droppy-pill look | ✓ SATISFIED (code) / ⚠️ DOC GAP | Code fully implements and matches spec (see Truth #1). **However**, `.planning/REQUIREMENTS.md` line 51 still shows `- [ ] **HUD-01**` (unchecked) and the Traceability table (line 115) still lists `HUD-01 \| Phase 36 \| Pending` — both stale, not updated to reflect completion, despite `ROADMAP.md` marking the whole phase `[x]` complete and `36-01-SUMMARY.md` documenting full completion. This is a documentation-tracking gap, not a code gap — recommend updating `REQUIREMENTS.md`'s checkbox and traceability row to `[x]`/`Complete` as a follow-up. |
| HUD-02 | 36-01 | Charging activity restyled to Droppy-pill look | ✓ SATISFIED (code) / ⚠️ DOC GAP | Same as HUD-01 above — code verified complete (Truth #2), `REQUIREMENTS.md` line 52 and traceability line 116 both still show unchecked/Pending. |
| EQ-01 | 36-02 | Equalizer bars redesigned to reference visual style | ✓ SATISFIED | Code verified (Truth #3). `REQUIREMENTS.md` line 43 and traceability line 117 correctly show `[x]`/Complete — consistent. |
| ONBOARD-04 | 36-03, 36-04 | Onboarding heading replaced by signature-style script heading | ✓ SATISFIED | Code verified against the D-14-pivoted wording (Truth #4). `REQUIREMENTS.md` line 47 and traceability line 118 correctly show `[x]`/Complete, and the requirement text itself was updated in commit `e3398d2` to match the pivot ("static rainbow-gradient signature-style script heading") — consistent. |

No orphaned requirements found — all 4 requirement IDs declared across the phase's plan frontmatter (`HUD-01`, `HUD-02` in 36-01; `EQ-01` in 36-02; `ONBOARD-04` in 36-03/36-04) are accounted for in `REQUIREMENTS.md`'s System HUDs / Now Playing Polish / Onboarding sections.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| `Islet/Notch/NotchPillView.swift` | 2444 | `abs(hasher.finalize()) % 1000` — `abs(Int.min)` traps (crashes) in Swift; `Hasher.finalize()`'s range includes `Int.min` | ⚠️ Warning (carried from 36-REVIEW.md WR-01, unfixed) | Astronomically unlikely (~1-in-2^64 per call) but the function runs continuously (every ~100ms per bar, 5 bars) for the app's entire Now-Playing lifetime — a live, unbounded-over-time crash surface, however negligible in practice. Does not block the phase goal (bars do render/animate correctly in the overwhelming case) but is an unresolved code-review finding worth tracking. |
| `Islet/Notch/NotchPillView.swift` | 1504-1506 | Comment above `SignatureHeading()` still reads "plain heading text replaced by the animated hand-drawn stroke-reveal" | ℹ️ Info | Stale comment left over from the pre-pivot plan; the actual code is the static gradient design (verified). Purely a documentation/comment accuracy issue, zero behavioral impact. |
| `Islet/Notch/NotchPillView.swift` / `Islet/SettingsView.swift` | 384-385, 2061, 2280 / 301 | `EqualizerBars.tint` parameter and the Settings "Now Playing" accent picker are now dead/disconnected from the bars (carried from 36-REVIEW.md IN-01/IN-02) | ℹ️ Info | Deliberate design choice (bars are fixed white per EQ-01 spec) but the accent picker's Settings label doesn't clarify this scope change — could read as a UI regression to a user who doesn't know the equalizer intentionally stopped following the accent color. Not a phase-goal blocker. |

No 🛑 Blocker-level anti-patterns found. No TBD/FIXME/XXX debt markers in any file this phase touched.

### Human Verification Required

### 1. Tap registration on the widened "Charging"/"Connected" wing labels

**Test:** With the app running, wait for (or simulate) a Charging or Bluetooth-connected wing to show its new label text, then tap directly on the label word itself (not the icon, not the right-wing battery/ring) while the island is in its collapsed state.
**Expected:** The tap expands the island (same behavior as tapping the icon or the notch itself) — click-through should not swallow the tap.
**Why human:** `36-REVIEW.md` (WR-02) found that `NotchWindowController.handlePointer(at:)` still gates click-through eligibility on the original, narrow `hotZone` (set once in `positionAndShow` to the collapsed-pill frame + 6pt padding, ~99pt half-width) rather than the newly-widened `wingsLabelWidth`/200pt half-width the label text now occupies. The panel-frame reservation is wide enough (confirmed, no visual clipping), but hit-testing eligibility is a separate code path this phase's widening measurably worsened. This can only be confirmed by an actual tap on real hardware — grep/build cannot simulate `NSEvent` hit-testing against the live panel geometry, and this specific interaction case was not part of any of the prior on-device UAT checkpoints (those tested visual appearance only, not tap-through behavior on the new label text specifically).

### Gaps Summary

No must-have truths failed. All 4 ROADMAP success criteria are code-verified against the actual shipped implementation, including ONBOARD-04's Success Criterion #4 judged correctly against the D-14-pivoted static-gradient wording (not the plan's original literal stroke-reveal wording, per the explicit instruction for this verification pass). Build succeeds; all referenced commits exist; no debt markers.

Two non-blocking items carried forward from `36-REVIEW.md` remain unresolved in the shipped code (WR-01's theoretical `abs(Int.min)` trap, WR-02's click-through hot-zone gap) — WR-01 is logged as a Warning anti-pattern (residual risk, not a goal-blocker), WR-02 is escalated as a Human Verification item because it plausibly affects real-world usability of the exact new UI element this phase shipped (the wing labels) and needs an on-device tap test to resolve, not a grep.

One documentation-tracking gap: `.planning/REQUIREMENTS.md`'s checkboxes/traceability rows for HUD-01 and HUD-02 were not updated to `[x]`/Complete despite the phase and its plans being fully implemented and the ROADMAP marking Phase 36 complete — recommend a follow-up edit to `REQUIREMENTS.md` (mechanical fix, not a re-open of implementation work).

---

_Verified: 2026-07-16T23:15:00Z_
_Verifier: Claude (gsd-verifier)_
