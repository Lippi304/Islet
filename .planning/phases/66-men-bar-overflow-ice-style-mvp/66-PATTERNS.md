# Phase 66: Menübar-Overflow (Debug-the-CGS-Spike MVP) - Pattern Map

**Mapped:** 2026-07-28 (full replacement — supersedes the prior 66-PATTERNS.md, written for the now-abandoned spacer-`NSStatusItem` technique, D-06/NO-GO'd in 66-04)
**Files analyzed:** 8 (2 restored-from-git, 1 new, 2 modified, 1 removed, 2 read-only reference)
**Analogs found:** 7 / 8

This phase pivots (D-07) from building a third mechanism to **debugging the original private-CGS spike** (git commit `adfbd70`) against real, currently-running Ice, plus adding two genuinely-new pieces the deleted spike never had: an enforced Accessibility gate and a persisted third-party assignment store. The pattern map below reflects that: most "patterns" are RESTORE + ADD-A-GATE instructions, not fresh design.

## File Classification

| New/Modified/Restored File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `Islet/Notch/MenuBarOverflowBridging.swift` | utility (private-API bridging shim) | request-response (CGS enumeration) + event-driven (synthetic CGEvent drag) | itself, at git `adfbd70` (exact prior version, signature-verified against Ice's real source per RESEARCH.md) | exact — restore verbatim, then add a gate at the call site |
| `IsletTests/MenuBarOverflowManualSpike.swift` | test (manual on-device spike) | request-response | itself, at git `adfbd70`, cloned in turn from `IsletTests/MeetingMonitorManualSpike.swift` (Cmd-U-only convention) | exact — restore, then upgrade the diagnostic print to a gate check |
| `Islet/Notch/MenuBarOverflowController.swift` | controller (menu-bar UI + mechanism orchestration) | request-response (chevron click) + CRUD (reveal/hide state) | itself, current on-disk version (66-02) — chevron/glyph half unchanged; internal mechanism call swapped | role-match — reuse the whole file, replace only `applyRevealedState`'s spacer-length lines |
| `Islet/Notch/MenuBarOverflowAssignmentStore.swift` | store (persistence) | CRUD | `Islet/ActivitySettings.swift` (flat `UserDefaults` key constants) — partial match only; no existing per-item-keyed dictionary store exists in this codebase | partial — genuinely new shape, see "No Analog Found" |
| `IsletTests/MenuBarOverflowClampTests.swift` | test | transform (pure function) | N/A — orphaned, remove | n/a (deletion, not a pattern target) |
| Accessibility gate (new code inside Bridging/Controller) | middleware/guard | request-response | `Islet/Notch/OSDInterceptor.swift:46` / `Islet/Notch/CapsLockMonitor.swift:34` (`isAccessibilityTrusted`) | exact |
| `Islet/AppDelegate.swift` (wiring + debug-menu real-launch check) | controller (app lifecycle wiring) | event-driven | itself, `applicationDidFinishLaunching` §113-287 (status-item construction order) + `setupDebugMenu()` §504-535 (debug-action pattern) | exact |
| `Islet/SettingsView.swift` (new permission row + explanation popover) | component (SwiftUI) | request-response | `capsLockPermissionExplanationView` (`SettingsView.swift:770-792`) + `permissionRow`/`permissionsSection` (`SettingsView.swift:560-622`) | exact |

## Pattern Assignments

### `Islet/Notch/MenuBarOverflowBridging.swift` (utility, restore + gate)

**Analog:** itself at `git show adfbd70:Islet/Notch/MenuBarOverflowBridging.swift` (208 lines, fully recovered this session, byte-for-byte signature-verified against Ice's real `Private.swift` per RESEARCH.md — do not redesign, only restore).

**Restore command:**
```bash
git show adfbd70:Islet/Notch/MenuBarOverflowBridging.swift > Islet/Notch/MenuBarOverflowBridging.swift
git show adfbd70:IsletTests/MenuBarOverflowManualSpike.swift > IsletTests/MenuBarOverflowManualSpike.swift
xcodegen generate   # re-register both files, removed from project.pbxproj by 66-03
```

**CGS symbol declarations (keep exactly as-is — verified correct, do not "fix"):**
```swift
// NOTE: CGSMainConnectionID() -> Int32 is already declared globally (FullscreenSpaceProbe.swift,
// Phase 2) — reused here as-is rather than re-declared.
@_silgen_name("CGSGetWindowCount")
func CGSGetWindowCount(_ cid: Int32, _ targetCID: Int32, _ outCount: inout Int32) -> CGError

@_silgen_name("CGSGetProcessMenuBarWindowList")
func CGSGetProcessMenuBarWindowList(
    _ cid: Int32, _ targetCID: Int32, _ count: Int32,
    _ list: UnsafeMutablePointer<CGWindowID>, _ outCount: inout Int32
) -> CGError
```

**The new work — gate `menuBarItemWindows()` before any CGS call** (was print-only in the deleted spike, this is Pitfall 1 from RESEARCH.md, the single highest-priority code change):
```swift
// BEFORE (deleted spike, never gated):
static func menuBarItemWindows() -> [MenuBarItemWindow] {
    var totalCount: Int32 = 0
    guard CGSGetWindowCount(CGSMainConnectionID(), 0, &totalCount) == .success, totalCount > 0 else { return [] }
    ...
}

// AFTER — add the gate as the very first line, mirroring OSDInterceptor.isAccessibilityTrusted below:
static func menuBarItemWindows() -> [MenuBarItemWindow] {
    guard AXIsProcessTrusted() else { return [] }   // NEW — was only ever printed, never branched on
    var totalCount: Int32 = 0
    ...
}
```

**Everything else in the file (enumeration loop, `moveMenuBarItem`, `wakeUpItem`, `menuBarItemEvent` field-stamping) restores verbatim** — no signature changes, per RESEARCH.md's "byte-for-byte match" finding.

---

### `IsletTests/MenuBarOverflowManualSpike.swift` (test, restore + gate check)

**Analog:** itself at `git show adfbd70` (69 lines, recovered this session), structurally cloned from `MeetingMonitorManualSpike.swift`'s Cmd-U-only convention.

**Restore verbatim, then change line 12's diagnostic print into a branch:**
```swift
// BEFORE (deleted spike):
print("[MenuBarOverflowSpike] AXIsProcessTrusted() = \(AXIsProcessTrusted())")
let windows = MenuBarOverflowBridging.menuBarItemWindows()

// AFTER — make the trust state impossible to miss in the on-device checkpoint, and note that
// menuBarItemWindows() itself now gates (so an untrusted run will correctly print 0 windows):
let trusted = AXIsProcessTrusted()
print("[MenuBarOverflowSpike] AXIsProcessTrusted() = \(trusted) — \(trusted ? "gate PASSES, enumeration will run" : "gate BLOCKS, expect 0 windows below")")
let windows = MenuBarOverflowBridging.menuBarItemWindows()
```

Test-file header convention to preserve (manual-only discipline, this codebase's established precedent):
```swift
// MANUAL SPIKE — DO NOT RUN VIA `xcodebuild test` (the full Islet.app test host hangs
// headless). Run via Xcode Cmd-U for THIS single test method only.
final class MenuBarOverflowManualSpike: XCTestCase {
    @MainActor
    func testManualMechanism() { ... }
}
```

---

### `Islet/Notch/MenuBarOverflowController.swift` (controller, keep UI, swap mechanism)

**Analog:** itself, current on-disk 66-02 version (114 lines) — the chevron construction, click handler, and glyph-swap are confirmed working on-device (66-04 UAT) and must be kept unchanged. Only the internal state-application call changes.

**Keep as-is (confirmed working, do not touch):**
```swift
// Islet/Notch/MenuBarOverflowController.swift:37-72 — status item construction + ordering
chevronItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
chevronItem.autosaveName = "IsletMenuBarOverflowChevron"
chevronItem.button?.target = self
chevronItem.button?.action = #selector(chevronPressed)

// lines 86-94 — glyph swap, confirmed working, reuse verbatim
private func applyRevealedState(_ revealed: Bool) {
    let symbolName = revealed ? "chevron.right" : "chevron.left"
    let accessibilityDescription = revealed ? "Hide Menu Bar Icons" : "Show Hidden Menu Bar Icons"
    let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)
    image?.isTemplate = true
    chevronItem.button?.image = image
}
```

**Replace (spacer.length toggle → CGS move + assignment store re-apply):**
```swift
// DELETE — the abandoned spacer-mechanism line inside applyRevealedState:
spacerItem.length = revealed ? Self.collapsedSpacerLength : Self.currentExpandedLength()

// DELETE the whole spacerItem/screenObserver/currentExpandedLength/recomputeIfHidden
// apparatus (lines 26, 47, 56-58, 63-72, 74-80, 96-107) — this was purely spacer-mechanism
// scaffolding (screen-width clamp, screen-change re-observer); the CGS mechanism has no
// screen-width dependency at all.

// ADD — after the Accessibility gate passes, re-apply the persisted assignment store's
// hidden set via MenuBarOverflowBridging.moveMenuBarItem(...) for each hidden item, mirroring
// Ice's "actively re-apply on every launch" architecture (RESEARCH.md Pattern 3).
```

**No analog exists in this codebase for "CGS move + assignment-store re-apply on launch" — this is new orchestration code, informed directly by RESEARCH.md Pattern 3 and the restored `MenuBarOverflowBridging.moveMenuBarItem` signature above.**

---

### Accessibility gate (new, embedded in Bridging/Controller call sites)

**Analog:** `Islet/Notch/OSDInterceptor.swift:46` and `Islet/Notch/CapsLockMonitor.swift:34` — this codebase's own, twice-proven-in-production pattern for exactly this permission bucket. Clone verbatim, do not invent a new abstraction.

```swift
// Source: Islet/Notch/OSDInterceptor.swift:46 (existing, shipped)
static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }
```

```swift
// Source: Islet/Notch/CapsLockMonitor.swift:49-56 (existing, shipped) — the gate-with-retry
// shape to mirror for MenuBarOverflowController.start(): untrusted → arm a 5s health-check
// retry instead of giving up until next relaunch (mid-session-grant race, Pitfall 3 of
// RESEARCH.md's own precedent chain).
func start() {
    guard monitorToken == nil else { return }
    guard Self.isAccessibilityTrusted else {
        armHealthCheck()
        return
    }
    install()
}
```

**Anti-pattern to avoid (this is literally what the deleted spike got wrong):** treating `AXIsProcessTrusted()` as a diagnostic print instead of a `guard`/branch. See RESEARCH.md Pitfall 1.

---

### `Islet/Notch/MenuBarOverflowAssignmentStore.swift` (NEW — D-03 persistence)

**No close analog in this codebase.** `Islet/ActivitySettings.swift` establishes the flat `UserDefaults` string-key constant convention (e.g. `static let menuBarOverflowRevealedKey = "menuBarOverflow.revealed"`, line 50) but nothing in this codebase currently stores a *dictionary keyed by dynamic per-item identity* in `UserDefaults` — every existing key is a single scalar (`Bool`/`String`/`Int`) toggle. Build this as a small, self-contained `Codable`-dictionary-in-`UserDefaults` store; there is no existing file to clone the shape from in this codebase.

**External reference shape to mirror (from RESEARCH.md, Ice's real source — mirror the *shape*, not the literal private key format):**
```swift
// Source: github.com/jordanbaird/Ice, Ice/MenuBar/MenuBarItems/MenuBarItemInfo.swift
// Ice's real identity model — namespace + title, not bundle ID alone (some apps expose
// >1 status item). RESEARCH.md Open Question 3: check on-device whether this MVP actually
// needs more than bundle-ID granularity before building the fuller shape.
struct MenuBarItemInfo: Hashable, CustomStringConvertible {
    let namespace: Namespace   // e.g. the owning bundle identifier
    let title: String
}
```

**Local convention to follow for the key constant itself** (mirrors `ActivitySettings.swift`'s existing flat-key style, just for the store's own single dictionary key, not per-item keys):
```swift
// Islet/ActivitySettings.swift:50 (existing convention to extend)
static let menuBarOverflowRevealedKey = "menuBarOverflow.revealed"
// New: e.g. static let menuBarOverflowHiddenAssignmentsKey = "menuBarOverflow.hiddenAssignments"
```

Required behavior (RESEARCH.md D-03 resolution, not optional): an **active re-apply pass** (re-issue `MenuBarOverflowBridging.moveMenuBarItem` for every persisted-hidden item) at app launch, after the Accessibility gate passes — the OS's own `autosaveName` mechanism does not cover third-party items (Pitfall 3).

---

### `Islet/AppDelegate.swift` (wiring — construction order + real-launch debug check)

**Analog:** itself, `applicationDidFinishLaunching` §281-287 (current construction-order comment/call) and `setupDebugMenu()` §504-535 (debug-menu-action pattern for Pattern 1 Step 3's real-launch-vs-Cmd-U comparison).

**Existing wiring to update (construction order comment now describes an abandoned mechanism, but the ORDER itself — after `statusItem`/`debugStatusItem` — still matters for D-01 and should be kept):**
```swift
// Islet/AppDelegate.swift:281-287 (current — comment needs rewriting for CGS, order unchanged)
menuBarOverflowController = MenuBarOverflowController()
menuBarOverflowController.start()
```

**Debug-menu pattern to reuse for the real-launch verification step (RESEARCH.md Pattern 1, Step 3 — "reuses the existing `debugStatusItem` debug-menu construction"):**
```swift
// Islet/AppDelegate.swift:504-535 (existing #if DEBUG debug menu, clone this shape)
#if DEBUG
private func setupDebugMenu() {
    debugStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    debugStatusItem.button?.title = "🐞"
    let debugMenu = NSMenu()
    debugMenu.addItem(withTitle: "Debug: Force Expired", action: #selector(debugForceExpired), keyEquivalent: "")
    // ... add: debugMenu.addItem(withTitle: "Spike: Print Menu Bar Overflow Enumeration", ...)
    for item in debugMenu.items { item.target = self }
    debugStatusItem.menu = debugMenu
}
#endif
```

---

### `Islet/SettingsView.swift` (new permission row + one-time explanation popover)

**Analog:** `capsLockPermissionExplanationView` (`SettingsView.swift:770-792`) for the popover shape (clone verbatim, per UI-SPEC.md's explicit instruction — "pixel-identical layout"), and `permissionRow`/`permissionsSection` (`SettingsView.swift:560-622`) for the new Settings row, **but this row is standalone, NOT a 6th `PermissionKind` case** (per UI-SPEC.md line 121 and RESEARCH.md's Supporting Stack note).

**Popover to clone verbatim (only title/body copy/URL change, per UI-SPEC.md's exact copy):**
```swift
// Source: Islet/SettingsView.swift:770-792 (capsLockPermissionExplanationView, existing, shipped)
private var capsLockPermissionExplanationView: some View {
    VStack(alignment: .leading, spacing: 8) {
        Text("Caps Lock HUD")
            .font(.system(size: 15, weight: .semibold))
        Text("Islet needs Accessibility access to detect Caps Lock. Islet only observes modifier-key state changes — it never reads, modifies, or sends anything else on your Mac.")
            .font(.system(size: 12))
            .lineSpacing(12 * 0.4)
        HStack {
            Button("Not Now") { showCapsLockPermissionExplanation = false }
            Spacer()
            Button("Open System Settings") {
                NSWorkspace.shared.open(URL(string:
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                showCapsLockPermissionExplanation = false
            }
            .keyboardShortcut(.defaultAction)
        }
    }
    .padding(16)
    .frame(width: 280)
}
```
New copy per UI-SPEC.md: title `"Menu Bar Overflow"`, body `"Islet needs Accessibility access to hide and reveal other apps' menu bar icons. Islet only repositions menu bar items — it never reads, modifies, or sends anything else on your Mac."`

**Row to clone the visual shape of, but NOT wire through `PermissionKind`/`permissionRow` (standalone, conditionally rendered only while untrusted):**
```swift
// Source: Islet/SettingsView.swift:600-622 (permissionRow, existing, shipped) — clone the
// HStack(icon, VStack(label, reason), Spacer, statusView) shape, whole-row tap target,
// .buttonStyle(.plain) — but as a freestanding view appended below permissionsSection's
// list (SettingsView.swift:566-582), NOT a new `permissionRow(kind:...)` call, and NOT
// counted in grantedPermissionCount's "X of 5" rollup.
private func permissionRow(kind: PermissionKind, label: String, icon: String,
                            reason: String, status: PermissionStatus) -> some View {
    Button { handlePermissionTap(kind: kind, status: status) } label: {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.system(size: 13))
                Text(reason).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            statusView(for: status)
        }
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(status == .granted)
}
```
New row visible only while `AXIsProcessTrusted() == false` (per UI-SPEC.md line 121), status pill text `"Accessibility Needed"` / `xmark.circle.fill` / `.red`, reusing the existing denied-pill color exactly (`SettingsView.swift:630-632`).

---

### `IsletTests/MenuBarOverflowClampTests.swift` (orphaned — remove)

**No analog needed — this file is being deleted, not replaced.** It unit-tests `clampedExpandedSpacerLength(candidate:screenWidth:)`, a pure function that lived in the now-abandoned `MenuBarOverflowController.swift`'s spacer apparatus (see that file's edit above — the whole screen-width-clamp mechanism is being deleted along with `spacerItem`). Once `clampedExpandedSpacerLength` is deleted from the controller, this test file has no function left to test and should be deleted in the same commit.

## Shared Patterns

### Accessibility permission gate
**Source:** `Islet/Notch/OSDInterceptor.swift:46`, `Islet/Notch/CapsLockMonitor.swift:34,49-56`
**Apply to:** `MenuBarOverflowBridging.menuBarItemWindows()` (hard gate, no CGS call without it), `MenuBarOverflowController.start()` (gate + 5s health-check retry, same shape as `CapsLockMonitor.start()`)
```swift
static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }
```

### "Isolate the fragile/uncertain thing behind its own seam"
**Source:** this codebase's established precedent (`NowPlayingMonitor`, `MicMuteController`, `MeetingMonitor`, and now `MenuBarOverflowBridging.swift` itself, restored)
**Apply to:** All private-CGS-symbol code stays confined to `MenuBarOverflowBridging.swift` — `MenuBarOverflowController.swift` and `AppDelegate.swift` only ever call into it, never declare `@_silgen_name` symbols themselves.

### One-time permission-explanation popover (own instance, never shared)
**Source:** `osdPermissionExplanationView` (`SettingsView.swift:738-762`), `capsLockPermissionExplanationView` (`SettingsView.swift:770-792`)
**Apply to:** the new Menu Bar Overflow explanation popover — same `VStack(spacing: 8)`/16px padding/280pt width/`"Not Now"` + `"Open System Settings"` button pair shape, gated on its own one-time `UserDefaults` flag (`hasShownMenuBarOverflowPermissionExplanation`), never a shared generic popover.

### Status-item construction order (D-01 leftmost-among-Islet's-own-items)
**Source:** `Islet/AppDelegate.swift:114` (`statusItem`), `:505` (`debugStatusItem`), `Islet/Notch/MenuBarOverflowController.swift:37-72` (chevron, constructed last → lands leftmost)
**Apply to:** Keep `menuBarOverflowController.start()` called AFTER both `statusItem` and (in DEBUG) `debugStatusItem` construction in `applicationDidFinishLaunching` — this ordering constraint is unrelated to the mechanism pivot and still holds.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `Islet/Notch/MenuBarOverflowAssignmentStore.swift` | store | CRUD | No existing per-item-dynamic-key `UserDefaults` dictionary store in this codebase — every existing key (`ActivitySettings.swift`) is a single flat scalar. The only available shape reference is Ice's own external source (`MenuBarItemInfo`/`StatusItemDefaults`, cited above under Pattern Assignments) — mirror its *shape* (stable identity → hidden `Bool`, active re-apply on launch), not literal code, since Islet cannot reuse Ice's own private-key format for items it doesn't own. |

## Metadata

**Analog search scope:** `Islet/Notch/*.swift` (menu-bar/permission/monitor files), `Islet/AppDelegate.swift`, `Islet/SettingsView.swift`, `Islet/PermissionStatus.swift`, `Islet/ActivitySettings.swift`, `IsletTests/*.swift`, plus git history (`git show adfbd70` and descendant diagnostic commits `5f231f3`/`6136d7f`/`68bb5a2`).
**Files scanned:** 12 (7 read in full this session: `MenuBarOverflowController.swift`, `OSDInterceptor.swift`, `CapsLockMonitor.swift`, `MenuBarOverflowClampTests.swift`, `PermissionStatus.swift`, plus targeted sections of `AppDelegate.swift` and `SettingsView.swift`; 2 recovered from git history in full: `MenuBarOverflowBridging.swift`, `MenuBarOverflowManualSpike.swift`; `ActivitySettings.swift` key list grepped).
**Pattern extraction date:** 2026-07-28
