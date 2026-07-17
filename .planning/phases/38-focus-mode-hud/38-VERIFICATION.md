---
phase: 38-focus-mode-hud
verified: 2026-07-17T03:20:00Z
status: gaps_found
score: 3/4 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 2/4
  gaps_closed:
    - "CR-01 — activityEnabled(_:) shared true-default for focusKey (fixed 38-08, confirmed live at NotchWindowController.swift:566-569)"
    - "CR-02/WR-02 — permission-grant completion never wired to the controller (fixed 38-08: SettingsView.swift:274-279 now calls NotchWindowController.focusPermissionGranted() → handleSettingsChanged(), confirmed live)"
  gaps_remaining:
    - "ROADMAP SC #2 ('toggling off dismisses it') — still failing, but for a DIFFERENT, newly-discovered reason unrelated to the two closed defects: handleFocusChange(false) never re-renders after flushing the Focus transient"
  regressions: []
gaps:
  - truth: "Toggling Focus/DND on shows the new HUD in a generic 'Focus On' state; toggling off dismisses it — no named-mode text anywhere (ROADMAP SC #2)"
    status: failed
    reason: "handleFocusChange(_:)'s false-branch calls flushTransients(.focus) but never calls renderPresentation()/updateVisibility() afterward, unlike every other flushTransients call site (handleSettingsChanged's unconditional tail) and unlike the on-branch's own presentTransientChange(). Traced the common real-world case independently against live source: Focus is the sole, persistent head (D-06 — isPersistent skips the auto-dismiss timer), nothing else queued (Charging/Device always preempt rather than queue behind Focus, so pending is empty). Real Focus/DND turns off -> FocusModeMonitor.poll() calls onChange(false) -> handleFocusChange(false) -> flushTransients(.focus): oldHead=.focus(.on), transientQueue.head becomes nil after removeAll(where:), the `head != oldHead` guard passes (a change occurred) so execution continues, but the following `if transientQueue.head != nil` block is skipped (new head IS nil) — so scheduleActivityDismiss() never runs AND, critically, nothing on this path ever calls renderPresentation(). presentationState.presentation (the @Published value NotchPillView renders) stays frozen at .focus(.on) indefinitely. The monitor keeps polling every 2.5s and calling handleFocusChange(false) again, but flushTransients's own oldHead-vs-new-head guard is false==false every subsequent time, so it never self-corrects via this path — only an unrelated event (hover/collapse, click, Now-Playing update, Charging/Device event) that happens to call renderPresentation() for its own reasons incidentally clears the stale Focus pill. This directly contradicts D-06 ('dismisses the instant Focus turns off') and ROADMAP SC #2's 'toggling off dismisses it'."
    artifacts:
      - path: "Islet/Notch/NotchWindowController.swift"
        issue: "handleFocusChange's else branch (lines 1600-1602) calls flushTransients(.focus) with no renderPresentation()/updateVisibility() tail, unlike handleSettingsChanged (lines 1762-1765) and presentTransientChange() (lines 742-757)"
    missing:
      - "In handleFocusChange's else branch, after flushTransients(.focus), add withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) { renderPresentation() } followed by updateVisibility() — mirroring handleSettingsChanged's tail exactly, per 38-REVIEW.md's suggested fix"
deferred: []
---

# Phase 38: Focus Mode HUD Verification Report

**Phase Goal:** A generic on/off Focus Mode HUD appears when the user toggles Focus/Do Not Disturb — an on-device research spike confirms the detection mechanism first, then the feature is built as the first genuinely new ActiveTransient case in this milestone, proving the "new pure Activity type → Monitor → resolver case → wing view" pipeline once, cheaply, before Phase 39 attempts the same pipeline under real private-API risk.
**Verified:** 2026-07-17T03:20:00Z
**Status:** gaps_found
**Re-verification:** Yes — after 38-08 gap-closure work, plus independent tracing of a NEW blocker surfaced by a fresh 38-REVIEW.md code review

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | An on-device spike confirms and records which detection path is used before full implementation proceeds | ✓ VERIFIED | `FocusModeMonitor.swift:11-17` header documents Path A (`INFocusStatusCenter`) won on-device; unchanged since last verification, re-confirmed live |
| 2 | Toggling Focus/DND on shows the new HUD in a generic "Focus On" state; toggling off dismisses it — no named-mode text anywhere | ✗ FAILED | The "on" path is correct and now reliably reachable (CR-01/CR-02/WR-02 both confirmed fixed — see below). BUT the "off" path is newly confirmed broken: `handleFocusChange(false)` (`NotchWindowController.swift:1593-1602`) flushes the transient but never re-renders (`flushTransients`, lines 1784-1805, has no render/visibility tail on this call site) — the Focus pill can get stuck visible indefinitely after Focus/DND actually turns off. Independently traced against live source, not accepted from `38-REVIEW.md` prose alone |
| 3 | If the FDA-gated path is required, denying that permission degrades silently rather than blocking the rest of the app | ✓ VERIFIED (path not applicable — Path A used, not FDA) | `FocusModeMonitor.poll()` (lines 56-63) guards on `.authorized` status and a non-nil `isFocused` read; does nothing (no crash, no `onChange`, no spin) otherwise. Unchanged and re-confirmed live |
| 4 | The new FocusActivity/FocusModeMonitor pipeline routes through IslandResolver/TransientQueue like every other transient — no resolver bypass | ✓ VERIFIED | `.focus` case correctly wired into `IslandResolver.resolve()` (collapsed-only per D-07, `IslandResolver.swift:59,75,120-121`), `TransientQueue.enqueue`/`preempt` handle it, `IslandResolverTests.swift` covers D-06/D-07/D-08 precedence. The new SC #2 defect is a missing render call AFTER a legitimate resolver-level flush, not a resolver bypass or a view-layer `@State` shortcut — the architecture itself is sound |

**Score:** 3/4 truths verified

### Independent Verification of All Code-Review Findings

Traced directly against live source (`git show HEAD` state, no reliance on `38-REVIEW.md` or any SUMMARY prose):

- **CR-01 (prior, `activityEnabled` default) — CONFIRMED FIXED.** `NotchWindowController.swift:566-569`:
  ```swift
  private func activityEnabled(_ key: String) -> Bool {
      let defaultValue = (key == ActivitySettings.focusKey) ? false : true
      return UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue
  }
  ```
  `focusKey` now gets an explicit `false` fallback, matching `SettingsView.swift:37`'s `@AppStorage(focusKey) private var focusEnabled = false`. Both call sites (`start()` line 474, `handleSettingsChanged()` line 1729) inherit the fix automatically via the shared helper.

- **CR-02/WR-02 (prior, permission-grant never wired to controller) — CONFIRMED FIXED.** `SettingsView.swift:273-282`:
  ```swift
  Button("Continue") {
      FocusModeMonitor.requestAuthorization { granted in
          DispatchQueue.main.async {
              if granted {
                  (NSApp.delegate as? AppDelegate)?.notchController?.focusPermissionGranted()
              }
              showFocusPermissionExplanation = false
          }
      }
  }
  ```
  `focusPermissionGranted()` (`NotchWindowController.swift:627-629`) calls `handleSettingsChanged()` — the same start-gate logic launch/toggle-flip already use — so a successful grant now actually starts `FocusModeMonitor` without requiring an undocumented toggle-off/on or app relaunch. Confirmed no other code path was needed; this closes both the monitor-never-starts defect and (per `handleSettingsChanged`'s own render tail) the stale-permission-hint half of WR-02.

- **NEW BLOCKER (this review) — CONFIRMED, independently traced, NOT just accepted from `38-REVIEW.md`.** Read `handleFocusChange` (`NotchWindowController.swift:1593-1603`), `flushTransients` (`:1784-1805`), `renderPresentation` (`:732-734`), `presentTransientChange` (`:742-757`), `updateVisibility` (`:766+`), and `handleSettingsChanged`'s tail (`:1762-1765`) directly. Confirmed the asymmetry the review describes is real: `handleSettingsChanged`'s Focus-off branch (`else if focusModeMonitor != nil { ...; flushTransients(.focus) }`) is followed unconditionally by the function's own `renderPresentation()`+`updateVisibility()` tail a few lines later — so Settings-driven disable is fine. `handleFocusChange`'s `else` branch is a bare, one-line `flushTransients(.focus)` with nothing after it and no shared tail to fall back on (it's a leaf function, unlike `handleSettingsChanged`). Traced the queue-state arithmetic by hand: with Focus as the sole persistent head and `pending` empty (the common real case, since Charging/Device preempt rather than queue behind Focus), `flushTransients` reduces `head` from `.focus(.on)` to `nil`, the `head != oldHead` guard is satisfied (so it does not early-return), but the subsequent `if transientQueue.head != nil` block — the ONLY place in this function that would call `scheduleActivityDismiss()` — is skipped because the new head is `nil`. Nothing in `flushTransients` calls `renderPresentation()` regardless of which branch runs; only `handleSettingsChanged`'s external tail provides that for its own call site. `handleFocusChange`'s off-branch has no equivalent, so `presentationState.presentation` is left stale at `.focus(.on)` until an unrelated code path (hover/click/Now-Playing/Charging/Device) happens to call `renderPresentation()` for its own reasons. This is a genuine, confirmed BLOCKER, contradicting D-06 and ROADMAP SC #2.

- **WR-01 (prior, `TransientQueue.preempt` bypasses `maxDepth`) — CONFIRMED STILL OPEN, unchanged, non-blocking.** `IslandResolver.swift:257-263`: `preempt(_:)` inserts the displaced Focus at `pending[0]` with no post-insert trim, unlike `enqueue(_:)`'s own bound check (`pending.count > maxDepth` trims from the front). Self-heals within ~2.5s via the next `FocusModeMonitor` poll re-enqueueing Focus; does not block the HUD from ever appearing. Kept as a warning per 38-REVIEW.md's own classification — out of scope for 38-08 and not part of this phase's must-haves resolution requirement.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/Notch/FocusModeMonitor.swift` | Thin Path-A detection glue, silent-degrade, polling | ✓ VERIFIED | Unchanged since last verification; isolated to Intents/INFocusStatusCenter |
| `Islet/Notch/FocusActivity.swift` | Pure single-case Activity + total mapping fn | ✓ VERIFIED | `enum FocusActivity { case on }`, total mapping fn, Foundation-only |
| `Islet/Notch/IslandResolver.swift` | `.focus` ActiveTransient case, resolver precedence, TransientQueue preempt | ✓ VERIFIED (wiring) / ⚠️ WR-01 queue-bound bug (non-blocking, unchanged) | `.focus` correctly wired into `resolve()` (collapsed-only, D-07); `preempt(_:)` unbounded insert still unfixed |
| `Islet/Notch/NotchPillView.swift` | Generic Focus wing, fixed white, no accent | ✓ VERIFIED | `focusWings(for:)` (line 2151) renders "Focus" text (line 2162) + moon icon, no accent reference |
| `Islet/SettingsView.swift` | Toggle defaults OFF, permission popover, status hint, grant callback | ✓ VERIFIED | `focusPermissionExplanationView`'s "Continue" button (lines 273-282) now threads the grant back to the controller |
| `Islet/Notch/NotchWindowController.swift` | Toggle-gated monitor lifecycle mirroring Charging/Devices | ⚠️ PARTIAL — `activityEnabled(_:)` fixed (CR-01), `focusPermissionGranted()` added (CR-02/WR-02), but `handleFocusChange`'s off-branch is missing its render tail (NEW BLOCKER) | Two of three known defects in this file are closed; one new one, found by fresh review and independently confirmed here, remains |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `SettingsView.swift` Toggle("Focus Mode HUD") | `FocusModeMonitor.requestAuthorization` | `.onChange(of: focusEnabled)` | ✓ WIRED | Fires on off→on flip, matching D-02 |
| `FocusModeMonitor.requestAuthorization` completion | `NotchWindowController.focusPermissionGranted()` → `startFocusModeMonitor()` | `focusPermissionGranted()` callback | ✓ WIRED (newly fixed) | Grant now reaches the controller and re-runs the start-gate; previously NOT_WIRED (CR-02/WR-02), confirmed fixed live |
| `NotchWindowController.handleFocusChange(true)` | `TransientQueue.enqueue`/`IslandResolver.resolve` | `presentTransientChange()` | ✓ WIRED | On-path correctly enqueues + renders + arms visibility |
| `NotchWindowController.handleFocusChange(false)` | `TransientQueue.removeAll` / re-render | `flushTransients(.focus)` | ✗ NOT_WIRED (render tail missing) | Queue mutation happens; the render/visibility step that would make the mutation observable never fires on this call site |
| `UserDefaults` focusKey write | `NotchWindowController.activityEnabled(focusKey)` | `activityEnabled(_:)` helper | ✓ WIRED (fixed) | Now uses the correct focusKey-specific `false` default |

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|----------------|--------------|--------|----------|
| HUD-05 | 38-01 through 38-08 (all) | A Focus Mode HUD appears when the user toggles Focus/DND, generic on/off state only | ✗ BLOCKED | The prior two system-glue defects (CR-01, CR-02/WR-02) are now closed and independently re-confirmed fixed. A newly-discovered, independently-confirmed BLOCKER (missing render call in `handleFocusChange`'s off-branch) means the "toggling off dismisses it" half of the requirement still does not reliably hold at runtime. `.planning/REQUIREMENTS.md:120` still lists HUD-05 as "Pending" — consistent with the still-open defect, not a stale-doc issue |

No orphaned requirements: HUD-05 is the only ID mapped to Phase 38 in REQUIREMENTS.md, and it appears in every plan's `requirements:` frontmatter (38-01 through 38-08).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `Islet/Notch/NotchWindowController.swift` | 1600-1602 | `handleFocusChange`'s off-branch calls `flushTransients` with no render/visibility tail, unlike every other call site | 🛑 Blocker | Directly causes SC #2's "toggling off dismisses it" to fail in the common case (Focus as sole persistent head) |
| `Islet/Notch/IslandResolver.swift` | 257-263 | `preempt(_:)` bypasses the `maxDepth` bound `enqueue(_:)` enforces | ⚠️ Warning | Queue-ordering hiccup, self-heals within ~2.5s, not HUD-blocking (unchanged from prior verification) |
| `Islet/Notch/NotchWindowController.swift` | 1594-1595 | `guard let activity = focusActivity(from: true)` is structurally-unreachable dead code (the argument is a literal `true`) | ℹ️ Info | Cosmetic only — no runtime impact (IN-01 in 38-REVIEW.md) |

No TBD/FIXME/XXX debt markers found in the phase's files.

### Behavioral Spot-Checks

Skipped — this is a native macOS app requiring a GUI build/run and physical Focus/DND toggling; not runnable via headless command in this environment. The new blocker was instead confirmed via hand-traced queue-state arithmetic against the live source (see "Independent Verification" above), which is deterministic and does not depend on runtime observation.

### Probe Execution

No `scripts/*/tests/probe-*.sh` files or probe references found for this phase — SKIPPED (Xcode/Swift GUI app phase, no shell probes).

### Human Verification Required

Given the new blocker directly affects SC #2, a code fix should land before another on-device UAT round is worth running. Once `handleFocusChange`'s off-branch is fixed, the following should be verified together (carrying forward the two scenarios `38-08-SUMMARY.md` deferred to end-of-phase, which are still outstanding and independent of the new blocker):

#### 1. Focus-off dismisses the HUD without requiring an unrelated event (NEW BLOCKER — must re-check after fix)

**Test:** With Focus Mode HUD enabled and authorized, toggle macOS Focus/DND ON (HUD appears), then toggle it OFF. Do NOT hover/click the island or trigger any other activity afterward — just watch.
**Expected:** The Focus pill disappears within one poll cycle (~2.5s) of toggling Focus off, with no further interaction needed.
**Why human:** Requires real OS-level Focus/DND state changes and observing live rendering; the queue-state trace above is a deterministic code proof but the fix itself (once applied) should be confirmed on-device.

#### 2. Fresh-install / toggle-still-OFF auto-start check (CR-01 fix re-confirmation)

**Test:** With the Settings "Focus Mode HUD" toggle showing OFF (reset via `defaults delete`, or confirmed never touched) AND `INFocusStatusCenter` authorization already granted from a prior session, quit and relaunch Islet. Toggle macOS Focus/DND ON via Control Center.
**Expected:** The Focus HUD should NOT appear — the toggle is OFF.
**Why human:** Requires a real prior-authorization state and a real app relaunch; deferred from `38-08-SUMMARY.md`'s Task 3, never yet run.

#### 3. First-grant flow without any toggle-off/on workaround (CR-02/WR-02 fix re-confirmation)

**Test:** With Focus/DND authorization never previously granted, flip the Settings "Focus Mode HUD" toggle ON, click "Continue" in the popover, grant the OS permission dialog — do nothing else (no re-toggle, no relaunch). Then toggle macOS Focus/DND ON.
**Expected:** The Focus HUD appears without any additional manual workaround.
**Why human:** Requires the real async OS authorization dialog and a from-scratch permission state; deferred from `38-08-SUMMARY.md`'s Task 3, never yet run.

### Gaps Summary

One CRITICAL defect remains, newly discovered by a fresh, independent code review (`38-REVIEW.md`) and independently re-confirmed here against live source (not accepted on the review's or any SUMMARY's prose alone):

**`handleFocusChange(false)` never re-renders after flushing the Focus transient.** `flushTransients(.focus)` correctly removes the Focus transient from `TransientQueue`, but nothing calls `renderPresentation()`/`updateVisibility()` afterward on this specific call site — every other `flushTransients` caller (`handleSettingsChanged`) has an unconditional render tail a few lines later in the same function; `handleFocusChange` is a leaf function with no such tail. In the common real case (Focus is the sole, persistent standing head; nothing else queued), this means `presentationState.presentation` stays frozen at `.focus(.on)` indefinitely after the real Focus/DND state turns off — the island keeps showing the Focus wing until some unrelated event (hover, click, Now-Playing update, Charging/Device event) incidentally triggers a re-render. This directly contradicts D-06 ("dismisses the instant Focus turns off") and ROADMAP Success Criterion #2 ("toggling off dismisses it").

The two PRIOR blocker defects (CR-01's `activityEnabled` shared-default bug, CR-02/WR-02's discarded permission-grant completion) are both confirmed fixed by gap-closure plan 38-08 and independently re-verified here by direct source reading — not just trusted from `38-REVIEW.md`'s or `38-08-SUMMARY.md`'s prose. Those closures are real; this phase has made genuine progress since the prior VERIFICATION.md (score improved 2/4 → 3/4), but a new, independent defect blocks the same success criterion the prior round also failed, for an unrelated root cause.

WR-01 (`TransientQueue.preempt` bound bypass) remains open, unchanged, and non-blocking, consistent with the prior verification and `38-REVIEW.md`'s own classification.

`38-08-SUMMARY.md`'s deferred Task 3 on-device UAT (both scenarios, testing the now-fixed CR-01/CR-02) has never actually been run — it should be combined with a re-test of the new blocker's fix into a single on-device verification pass once the fix lands.

Because the new defect is BLOCKER-level and directly contradicts ROADMAP Success Criterion #2, this phase cannot be marked passed. A follow-up closure plan should target `NotchWindowController.swift`'s `handleFocusChange` off-branch (the fix suggested in `38-REVIEW.md`'s CR-01 section — its renumbered CR-01, not to be confused with the now-closed original CR-01) — and should bundle the three outstanding on-device human-verification items above into one UAT pass.

---

_Verified: 2026-07-17T03:20:00Z_
_Verifier: Claude (gsd-verifier)_
