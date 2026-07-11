---
phase: 23
slug: shell-parity-rewrite
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-11
---

# Phase 23 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing, `IsletTests/` target) — `NotchPanelTests.swift` covers panel construction properties; `InteractionStateTests.swift` covers the pure state machine; `FullscreenDetectorTests.swift`/`VisibilityDecisionTests.swift` cover the pure gates. No `NotchWindowControllerTests.swift` exists — the 1,378-line AppKit glue controller has never had direct unit tests (integration-heavy AppKit code, consistent with every prior phase's convention). |
| **Config file** | `project.yml` (XcodeGen) — scheme `Islet`, test target already wired |
| **Quick run command** | `xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build` (compile-only gate — `xcodebuild test` hangs headlessly hosting the full app boot; see project memory `xcodebuild-test-headless-hang`) |
| **Full suite command** | Manual **Cmd-U in Xcode** (existing project-wide convention since Phase 20/21/22) |
| **Estimated runtime** | ~30-60s build gate per commit; manual Cmd-U + on-device UAT pass is untimed |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build` (build gate only)
- **After every plan wave:** Manual Cmd-U for `NotchPanelTests`/`InteractionStateTests`/`VisibilityDecisionTests`/`FullscreenDetectorTests` + a manual on-device spot-check
- **Before `/gsd:verify-work`:** Full consolidated on-device UAT below, PLUS Cmd-U green
- **Max feedback latency:** ~60s (build gate); on-device UAT is untimed and reserved for the phase gate

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 23-01-* | 01 | 1 | ARCH-01 (panel construction properties) | — | Borderless, non-activating, never-key/main, `.statusBar`, correct `collectionBehavior`, starts click-through, transparent, zero `NSDraggingDestination` residue | unit | Cmd-U `NotchPanelTests` (add assertion: `NotchPanel` no longer conforms to `NSDraggingDestination` / registers dragged types) | ✅ existing, needs 1 new assertion | ⬜ pending |
| 23-01-* | 01 | 1 | ARCH-01 (pure state machine, unaffected) | — | `nextState(...)` transitions incl. `.dragEntered` (inert, Phase-24-reusable) | unit | Cmd-U `InteractionStateTests` | ✅ (zero-diff expected) | ⬜ pending |
| 23-01-* | 01 | 1 | ARCH-01 (fullscreen gate, unaffected) | — | `shouldShow(...)` pure predicate | unit | Cmd-U `VisibilityDecisionTests`/`FullscreenDetectorTests` | ✅ (zero-diff expected, out of phase scope) | ⬜ pending |
| 23-0X-* | all | all | ARCH-01 (position/hover/click/grace-collapse/fullscreen-hide/click-through/multi-Space — Success Criteria #1-4) | — | Live AppKit integration behavior — NOT unit-testable, requires real Window Server / pointer / Space transitions | manual (on-device) | N/A — see Consolidated On-Device UAT below | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `NotchPanelTests.swift` — add one assertion confirming `NotchPanel` no longer conforms to `NSDraggingDestination` / registers dragged types (covers Success Criterion #4 at the unit level, supplementing on-device confirmation)
- [ ] No new test framework/config needed — `IsletTests` target already exists and builds
- [ ] No `NotchWindowControllerTests.swift` gap to fill — consistent with every prior phase's convention (the controller is integration-only, not unit-testable), not a new gap introduced by this phase

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Hover/click feel, morph quality, grace-collapse | ARCH-01 (SC #1) | Live AppKit/Window Server behavior, not unit-testable | Hover fires haptic+bounce without expanding; click expands with spring morph; pointer-leave collapses after ~0.4s grace; quick re-entry cancels collapse; full expand↔collapse cycle is one continuous morph with no cross-fade/flicker/jump |
| Fullscreen hide/restore (3 trigger methods) | ARCH-01 (SC #2) | Requires real fullscreen Space transitions via green-button, menu bar, and a fullscreen video app | Island hides completely (no ghost bar) on all 3 triggers; restores on exit without stealing focus; maximized-but-not-fullscreen window leaves island visible; QuickLook fullscreen also hides it |
| Click-through, incl. CR-01 regression trace | ARCH-01 (SC #2) | Explicitly does not reduce to a grep/build gate per project memory `cr01-clickthrough-or-defeat-gotcha` | With shelf EMPTY: hover→click to expand→move pointer DOWN into the reserved-but-invisible empty shelf band→confirm click there passes through→move back into the visible blob→confirm click there is captured |
| Multi-Space visibility, display/clamshell repositioning | ARCH-01 (SC #3) | Requires real external-display/clamshell hardware state changes | Island stays visible across 2+ ordinary Spaces; repositions correctly through external-display connect/disconnect and clamshell open/close; no flicker/stuck-hidden/stuck-shown; only ever shows on the built-in notched display |
| Lock-screen / sleep-wake stability | ARCH-01 (general regression) | OS-level power state transition | Island behaves correctly across lock/sleep/wake cycles |

*Full consolidated ~20-item checklist (Phase 2 UAT + Phase 9 fullscreen matrix + CR-01 trace, git-recovered) is documented in `23-RESEARCH.md` under "Consolidated On-Device UAT" — run as ONE phase-gate pass given ARCH-01's "zero behavioral regression" framing. Only fall back to a lighter spot-check if the actual rewrite diff is small/mechanical (planner's call once diff shape is known, per CONTEXT.md).*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s (build gate)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
