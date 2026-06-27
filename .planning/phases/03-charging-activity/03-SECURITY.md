---
phase: 3
slug: charging-activity
status: verified
threats_open: 0
asvs_level: 1
created: 2026-06-27
---

# Phase 3 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| IOKit power-source read → app | App reads a CFDictionary of power-source values supplied by the OS; keys/values may be missing or malformed mid-transition. No network, no user input, no persistence. | Battery percent + charging state (non-sensitive, already user-visible) |
| `@convention(c)` callback → Swift object | The C run-loop callback recovers the `PowerSourceMonitor` instance through a raw `context` pointer — a lifetime boundary (use-after-free risk if the source outlives the object). | Object reference (memory-safety) |
| Notification thread → main thread / `@Published` / AppKit | The callback may run off-main; mutating `@Published`/AppKit there is a data race. | UI state mutation |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-03-01 | Tampering | `powerActivity(from:)` percent handling | mitigate | Percent clamped via `min(max(r.percent, 0), 100)` — malformed/out-of-range reading can't produce an invalid percent. `PowerActivity.swift:33`; covered by testPercentClampedLow/High. | closed |
| T-03-02 | Denial of Service | `shouldTriggerSplash` debounce | mitigate | Connect-edge predicate prevents splash re-fire on every percent tick; a `%` tick does not restart the dismiss timer. `PowerActivity.swift:49-51`, `NotchWindowController.swift:390-395`. | closed |
| T-03-03 | Information Disclosure | wings layout content | accept | Only `"\(percent)%"` is rendered (`NotchPillView.swift:148`) — battery percent already user-visible in the menu bar. No PII, no secrets. See Accepted Risks Log. | closed |
| T-03-04 | Tampering | `variableValue` argument | mitigate | `Double(percent)/100.0` is fed an already-clamped 0...100 value (T-03-01), so the symbol fill ratio stays 0.0...1.0. `NotchPillView.swift:145`. | closed |
| T-03-05 | Tampering / DoS | `readCurrentPower()` CFDictionary reads | mitigate | Every value read with optional cast + default (`as? Bool ?? false`, `as? Int ?? 0`); empty-list / no-battery path returns `isPresent: false` — no force-unwrap on missing/malformed keys. `PowerSourceMonitor.swift:30-34,44-50,53-54`. | closed |
| T-03-06 | Elevation / use-after-free | `@convention(c)` callback `context` pointer lifetime | mitigate | `Unmanaged.passUnretained(self).toOpaque()` paired with mandatory source removal: `stop()` calls `CFRunLoopRemoveSource`, invoked from `NotchWindowController.deinit`. `PowerSourceMonitor.swift:75,97-104`, `NotchWindowController.swift:428`. | closed |
| T-03-07 | Tampering / data race | callback mutating `@Published`/AppKit off-main | mitigate | Callback recovers `self`, then `DispatchQueue.main.async { ... }` BEFORE any `@Published`/AppKit/onChange touch. `PowerSourceMonitor.swift:81-83`. | closed |
| T-03-08 | Denial of Service | notification firing on every capacity tick | mitigate | `shouldTriggerSplash` gates re-display to connect edges; a pure `%` tick updates a standing splash without restarting the ~3s dismiss timer. `NotchWindowController.swift:378,390-395`. | closed |
| T-03-09 | Information Disclosure | splash leaking over a fullscreen app | mitigate | Splash never calls `orderFront` directly; power path routes solely through `updateVisibility()`, and `orderFrontRegardless` is gated by the `shouldShow` fullscreen check. `NotchWindowController.swift:251,386-389`. | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-03-01 | T-03-03 | Charging wings render only the battery percentage, which is already user-visible in the macOS menu bar. No PII, secrets, or otherwise sensitive data crosses the rendering boundary. Severity: low. | Niklas Lippert | 2026-06-27 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-06-27 | 9 | 9 | 0 | gsd-security-auditor (ASVS L1) |

### Audit Notes

- `shouldTriggerSplash` was revised during on-device UAT (Plan 03, commit `7489657`): the original category-transition predicate was replaced with a stricter connect-only edge predicate (`isOnAC(next) && !isOnAC(previous)`). This is tighter than the plan claimed and does not open a gap for T-03-02 or T-03-08.
- CHG-02 (on-battery unplug indication) was intentionally descoped by product decision during UAT. The `.onBattery` case remains in the model but `shouldTriggerSplash` never fires on it — a product change, not a security gap.
- `PowerSourceMonitor.deinit` intentionally does not call `stop()` (it can't be `@MainActor` in Swift 5 mode). Teardown is delegated entirely to `NotchWindowController.deinit`, which calls `powerMonitor.stop()` — the source removal required by T-03-06 is present.
- No `## Threat Flags` section was present in any Phase-3 summary; no unregistered threats surfaced.

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-06-27
