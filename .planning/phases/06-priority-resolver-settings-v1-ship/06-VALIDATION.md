---
phase: 6
slug: priority-resolver-settings-v1-ship
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-28
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Locked TDD discipline: pure logic unit-tested in ms; IOBluetooth / AppKit / SwiftUI / release wiring verified on-device. On-device Bluetooth UAT and real Developer-ID notarize/staple are accepted carry-overs (CONTEXT D-01, D-15).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (`@testable import Islet`), hosted in the `Islet` app target |
| **Config file** | `project.yml` → `IsletTests` (`bundle.unit-test`, `TEST_HOST = Islet.app`); ~10 existing test files |
| **Quick run command** | `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/IslandResolverTests` |
| **Full suite command** | `xcodebuild test -scheme Islet -destination 'platform=macOS'` |
| **Estimated runtime** | Pure-logic targets ~seconds; full app-hosted suite ~30–90s (build + host launch) |

---

## Sampling Rate

- **After every task commit:** Run the quick command scoped to the touched pure-seam test (`-only-testing:IsletTests/<Suite>`).
- **After every plan wave:** Run the full suite — must stay green (Phase-5 baseline ~102+ tests, no regressions).
- **Before `/gsd-verify-work`:** Full suite green + manual on-device checks below performed (or explicitly logged as deferred carry-overs).
- **Max feedback latency:** quick pure-seam run < ~15s.

---

## Per-Task Verification Map

> Task IDs are finalized by the planner. Rows below bind each phase requirement / locked decision to its verification surface.

| Item | Requirement | Decision | Secure/Correct Behavior | Test Type | Automated Command | File Exists | Status |
|------|-------------|----------|-------------------------|-----------|-------------------|-------------|--------|
| Resolver rank | COORD-01 | D-02/D-04 | Rank Charging > Device > Now Playing; transient briefly wins over expanded, then yields to highest-priority ambient | unit | `…-only-testing:IsletTests/IslandResolverTests` | ❌ Wave 0 | ⬜ pending |
| Transient queue | COORD-01 | D-03 | Second simultaneous splash enqueues (A then B); queue bounded + de-duped; advances off one-shot DispatchWorkItem (no repeating timer) | unit | `…-only-testing:IsletTests/IslandResolverTests` | ❌ Wave 0 | ⬜ pending |
| Single arbiter routing | COORD-01 | D-05 | Resolver is the sole presentation source, routed through `updateVisibility()`; scattered `if`-chain removed | unit + manual | `…-only-testing:IsletTests/IslandResolverTests` | ❌ Wave 0 | ⬜ pending |
| Device edge predicate | DEV-01/DEV-02 | 05 D-01…D-07 | connect/disconnect edges, glyph-by-name, dimmed disconnect, burst-suppression/debounce, ~3s dismiss | unit | `…-only-testing:IsletTests/DeviceActivityTests` | ✅ exists | ⬜ re-run |
| DeviceActivityState / BluetoothMonitor | DEV-01/DEV-02 | D-01 | @Published model + IOBluetooth monitor (main-hop, deinit teardown); device wings branch | manual (on-device) | — (BT UAT deferred) | ❌ Wave 1+ | ⬜ pending |
| Activity toggles | APP-03 | D-06/D-07/D-08/D-09 | Three on/off toggles, default ON, persist across restarts, apply live (prefer not registering source when off) | unit (persistence/exclusion) + manual | `…-only-testing:IsletTests/SettingsTests` (if pure seam extracted) | ❌ Wave 0/1 | ⬜ pending |
| Accent palette | APP-03 | D-10/D-11/D-12 | Curated ~5–6 swatches, default neutral; persists; tints bolt/glyph, equalizer bars, device icon only | unit (selection/persist) + manual (visual) | `…-only-testing:IsletTests/SettingsTests` | ❌ Wave 0/1 | ⬜ pending |
| Now Playing health re-check | APP-04 | D-16 | Launch-time health check + "nicht verfügbar" fallback still pass on current macOS | manual (on-device) | — | n/a | ⬜ pending |
| Release dry-run | APP-04 | D-15 | `scripts/release.sh` exits 0 with loud SKIP banner (placeholder Developer-ID), hdiutil UDZO DMG produced | manual (CLI) | `scripts/release.sh` | ✅ exists | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `IsletTests/IslandResolverTests.swift` — covers COORD-01 rank ordering + queue ordering/dedup/bound (the one genuinely new pure seam).
- [ ] Settings persistence/exclusion logic exposed as a pure-testable seam where feasible (toggle → ranking exclusion; accent selection → persisted value), so APP-03 has automated coverage beyond manual visual checks.
- [ ] No new fixtures/conftest needed — XCTest, values constructed by hand as existing tests do.
- [ ] Framework already installed (`IsletTests` exists) — no install step.

*Existing infrastructure covers device-edge and power/now-playing seams.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| IOBluetooth connect/disconnect → device splash | DEV-01/DEV-02 | Needs a real paired Bluetooth audio device (none available) — carry-over (D-01) | Connect/disconnect AirPods; confirm device wings appear ~3s then yield; dimmed disconnect; deinit teardown leaves idle CPU ~0% |
| TCC / `NSBluetoothAlwaysUsageDescription` (A1) verdict | DEV-01/DEV-02 | Requires running the real monitor on hardware | Observe whether connect notifications fire without the key; add key to `project.yml` only if required |
| Accent visuals across the three glyphs | APP-03 | Visual correctness can't be asserted in unit tests | Toggle each swatch; confirm bolt/glyph, equalizer bars, device icon tint; expanded chrome unchanged (D-11) |
| Toggle live-apply + persistence across restart | APP-03 | Cross-launch + live UI behavior | Disable each activity, confirm splash suppressed immediately; relaunch, confirm choices persisted |
| Now Playing launch-time health check (D-16) | APP-04 | Depends on installed macOS + mediaremote-adapter at runtime | Launch app; confirm health check passes (or "nicht verfügbar" fallback) on current macOS 26 build |
| Real Developer-ID sign → notarize → staple → clean second-Mac open | APP-04 | Needs $99/yr account + a second Mac | Carry-over (D-15); Phase 6 ships the pipeline as a dry-run only |

---

## Validation Sign-Off

- [ ] All tasks have automated verify or a Wave 0 dependency (or are listed Manual-Only with justification)
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers the new resolver seam (IslandResolverTests)
- [ ] No watch-mode flags
- [ ] Feedback latency < ~15s for the quick pure-seam run
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
