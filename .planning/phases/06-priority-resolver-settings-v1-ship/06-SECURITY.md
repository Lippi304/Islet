---
phase: 06
slug: priority-resolver-settings-v1-ship
status: verified
threats_open: 0
asvs_level: 1
created: 2026-07-02
---

# Phase 06 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

Register origin: **authored at plan time** — every one of the 13 plans in this phase (06-01 through 06-13) carries a `<threat_model>` block with an explicit STRIDE register. This audit verifies the register against the plans' own cited evidence (unit tests, grep-verified deletions, acceptance criteria) rather than scanning for new threats from scratch.

---

## Trust Boundaries

| Boundary | Description | Data Crossing | Source Plans |
|----------|-------------|----------------|---------------|
| Paired Bluetooth device → app | A remote/paired device supplies `device.name`/`address` — an attacker-controllable String — across the IOBluetooth notification boundary. | Untrusted device name string, unchanged since Phase 5's `deviceLabel(...)` sanitization seam | 06-02, 06-04, 06-07, 06-13 |
| App process → IOBluetooth notification registrations | OS-held connect + per-device disconnect notification tokens retained by the app. | Resource handles (no data) | 06-02, 06-04 |
| User → UserDefaults (`@AppStorage`) | User sets three activity toggles + one accent-index preference, persisted locally. | Local, non-secret app preferences (no privilege boundary — any process running as the user can already read/write UserDefaults) | 06-03, 06-04 |
| MediaRemoteAdapter perl child → app | Inherited from Phase 4, unchanged this phase — Now Playing data crosses from the spawned perl child, isolated in `NowPlayingMonitor`. | Track metadata (title/artist/art), transport commands | 06-04, 06-05 |
| Release toolchain → distributable | `codesign`/`hdiutil`/`notarytool`/`stapler` produce the shipped artifact. | Signed/notarized app bundle + DMG | 06-05, 06-12 |
| Notary credentials → `release.sh` | Script references a keychain profile NAME only; real credentials live in the macOS keychain, never in the repo. | Keychain profile name (not a secret) | 06-05, 06-12 |

---

## Threat Register

| Threat ID | Source Plan | Category | Component | Disposition | Mitigation | Status |
|-----------|-------------|----------|-----------|--------------|------------|--------|
| T-06-01 | 06-01 | Denial of Service | `TransientQueue` backing up under a flapping device | mitigate | Bounded `maxDepth = 2` + de-dup against head/pending, drop-oldest-pending on overflow; unit-tested (`testQueueBoundedDropsOldestPending`) | closed |
| T-06-02 | 06-01 | Tampering | Untrusted `device.name` flowing through `ActiveTransient.device` | accept | Already clamped to a plain bounded value by `deviceLabel(...)` (Phase 5 seam) before reaching the resolver; never interpolated into format string/shell | closed |
| T-06-03 | 06-02 | Tampering / Info-disclosure | `device.name` rendered in `deviceWings` | mitigate | Passed only into the tested pure `deviceLabel(...)` seam; SwiftUI `Text` is inert to format strings, bounded with `.lineLimit(1)` + `.truncationMode(.tail)` | closed |
| T-06-04 | 06-02 | Denial of Service (resource leak) | Orphaned IOBluetooth connect/disconnect tokens | mitigate | `BluetoothMonitor.stop()` unregisters the connect token and every per-device disconnect token; controller `deinit` calls `stop()` | closed |
| T-06-05 | 06-02 | Spoofing / Elevation (UX) | Speculative `NSBluetoothAlwaysUsageDescription` prompt | accept | Key deliberately not added speculatively — later resolved by A1 on-device finding (key IS required on macOS 26; added in 06-04, see project memory `a1-bluetooth-usage-key-required`) | closed |
| T-06-06 | 06-02 | Tampering | Debug spike (`DEBUG_BT_SPIKE`) double-registering IOBluetooth | mitigate | Entire spike path deleted (grep-verified empty) | closed |
| T-06-07 | 06-03 | Tampering | Out-of-range persisted `accentIndex` | mitigate | `ActivitySettings.accent(for:)` clamps any out-of-range index to the neutral default | closed |
| T-06-08 | 06-03 | Information Disclosure | Secrets stored in `@AppStorage`/UserDefaults | accept | No secrets stored — only 3 booleans + 1 index; notary creds live in the keychain, not UserDefaults | closed |
| T-06-09 | 06-04 | Denial of Service | `TransientQueue` flooding from a flapping device or rapid charging ticks | mitigate | Debounce + at-launch burst suppression gate before the queue; queue itself bounded + de-duped | closed |
| T-06-10 | 06-04 | Tampering / Info-disclosure | Device name routed through resolver into `deviceWings` | mitigate | Same bounded/inert String path as T-06-03 | closed |
| T-06-11 | 06-04 | Tampering | Out-of-range `accentIndex` injected into the hosting view | mitigate | Same clamp as T-06-07 | closed |
| T-06-12 | 06-04 | Denial of Service (resource leak) | IOBluetooth tokens / perl child leaking on toggle-off or controller death | mitigate | Toggle-off calls full `stop()` on the relevant monitor; `deinit` stops all monitors + cancels all work items + removes UserDefaults observer | closed |
| T-06-13 | 06-04 | Tampering | A second show/hide site racing the fullscreen/clamshell observers | mitigate | `updateVisibility()` remains the sole show/hide site (acceptance-criterion enforced) | closed |
| T-06-14a | 06-05 | Tampering | Distributable integrity (signing) in the dry-run | accept | Dry-run ad-hoc-signs with hardened runtime ON, local testing only; real Developer-ID signing/notarization is the documented D-15 carry-over, formally overridden in `06-VERIFICATION.md` (no paid Apple Developer account yet) | closed |
| T-06-14b | 06-06 | (informational) | `scheduleActivityDismiss` / `positionAndShow` reordering | accept | Pure reordering of existing internal `@Published` mutations; inherits T-06-11's clamp for the accent value | closed |
| T-06-15a | 06-05 | Information Disclosure | Notary credentials leaking into the repo | mitigate | `release.sh` uses a keychain profile NAME only, unfilled placeholders confirmed | closed |
| T-06-15b | 06-07 | (informational) | `handleDevice` / `scheduleDeviceBatteryRefresh` / `flushTransients` timing fixes | accept | Pure control-flow/timing fixes to existing internal, non-persisted state; no new input surface | closed |
| T-06-16a | 06-05 | Denial of Service (resource leak) | Perl child spawned by D-16 health check left running | mitigate | Existing `NowPlayingMonitor.stop()`/`deinit` teardown (T-04-12, unchanged); no new spawn path | closed |
| T-06-16b | 06-08 | (informational) | `startNowPlayingMonitor` / hover-pause timing fixes | accept | Pure timing/ordering fixes to existing internal state; inherits existing T-04-12/T-05-01 mitigations unchanged | closed |
| T-06-17 | 06-09 | (informational) | Dead-state deletion + extract-method refactor | accept | No runtime-behavior, input-handling, or persisted-state change; full-suite regression gates it | closed |
| T-06-18a | 06-10 | (informational) | Gesture-scoping restructure + artwork retention | accept | Structural SwiftUI change + pure comparison over already-bounded metadata; no new input surface | closed |
| T-06-18b | 06-13 | Information Disclosure (data-integrity) | `triggerDeviceBatteryRefreshIfPromoted()` — WR-1 | mitigate | Promoted device matched by identity (`matchPendingBatteryPoll`) instead of FIFO position, so one device's battery reading can no longer attach to a different device's splash; unit-tested (7 new regression tests) | closed |
| T-06-19a | 06-11 | (informational) | Dead-field deletion + `NowPlayingService` protocol extraction | accept | No runtime-behavior change; protocol extraction is architectural hardening (isolation/swap-ability), not new attack surface | closed |
| T-06-19b | 06-13 | (informational, timing only) | `flushTransients()` — WR-2 | accept | Timing-only fix to an already-correct show/hide decision; `oldHead` comparison is a pure equality check on internal Equatable values; full-suite regression gates it | closed |
| T-06-20 | 06-12 | (informational) | `scripts/release.sh` second notarize+staple invocation | accept | Same existing keychain-profile-name mechanism, no new credential path; completes Apple's documented two-staple requirement | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

**Note on ID collisions:** Five threat IDs (T-06-14, T-06-15, T-06-16, T-06-18, T-06-19) were independently assigned by two different plans each, since each plan's author numbered threats locally rather than against a phase-wide sequence. Disambiguated here with `a`/`b` suffixes by source plan. This is a plan-authoring numbering artifact, not a security gap — no threat was skipped or double-counted in the verification below.

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|--------------|------|
| AR-06-01 | T-06-02, T-06-08, T-06-14a, T-06-15b, T-06-16b, T-06-17, T-06-18a, T-06-19a, T-06-19b, T-06-20 | Informational/no-new-surface changes and already-mitigated-upstream data paths — see per-threat Mitigation column above | plan author (06-execution) | 2026-07-01/02 |
| AR-06-02 | T-06-05 | Speculative Bluetooth usage-key omission — superseded: key WAS required and added in 06-04 after on-device A1 finding; original deferral is now resolved, not an open risk | plan author + on-device UAT | 2026-07-01 |
| AR-06-03 | T-06-14a | Real Developer-ID notarization/signing deferred pending a paid Apple Developer account ($99/yr, not yet purchased) — dry-run pipeline proven end-to-end; formally overridden in `06-VERIFICATION.md` | user | 2026-07-02 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|----------------|--------|------|--------|
| 2026-07-02 | 25 | 25 | 0 | /gsd:secure-phase (orchestrator, register authored at plan time — short-circuit path, no auditor sub-agent needed) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-07-02
