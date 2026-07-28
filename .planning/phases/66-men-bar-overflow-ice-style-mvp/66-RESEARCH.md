# Phase 66: Menübar-Overflow (Debug-the-CGS-Spike MVP) - Research

**Researched:** 2026-07-28 (full replacement — supersedes the 2026-07-27 spacer-technique research below in full, after Plan 66-04's on-device NO-GO and CONTEXT.md's second pivot back to debugging the original private-CGS mechanism against real, working Ice)
**Domain:** Debugging Islet's own private-CGS menu-bar-item enumeration/repositioning spike (Plan 66-01, NO-GO'd, now deleted per Plan 66-03 but fully recoverable from git history) against real jordanbaird/Ice's actual working mechanism on this exact machine — plus re-opening the Accessibility permission gate (MENUBAR-04) that mechanism requires.
**Confidence:** MEDIUM-HIGH for the concrete, source-verified findings below (byte-for-byte CGS signature comparison, Ice's real permission-gating source, Ice's real persistence mechanism); LOW-MEDIUM for the actual root-cause diagnosis, which remains a hypothesis until confirmed on-device — this research narrows the search space with evidence, it does not close the case.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Mechanism (revised 2026-07-28 — second pivot)
- **D-07 (NEW, supersedes D-06):** Do NOT build a third blind mechanism variant. Debug Plan 66-01's private-CGS spike (`MenuBarOverflowBridging.swift`/`MenuBarOverflowManualSpike.swift`, currently deleted per 66-03 but present in git history) against **real, currently-running Ice** on this machine — find where Islet's CGS enumeration diverges from Ice's actual working behavior, fix it, re-verify on-device. Only if debugging genuinely dead-ends should a different mechanism be considered, and that requires a return to discussion.
- **D-06 (SUPERSEDED, kept for history):** The spacer-`NSStatusItem` technique — NO-GO'd on-device in Plan 66-04.
- **Live reference setup:** Ice is installed on the machine per the user's account but not currently running. The debugging plan must start with launching Ice. **Research finding (below): the installed Ice.app binary is not actually present on disk right now — see Environment Availability. This must be resolved (reinstall) before Ice can serve as a live comparison target.**
- **Diagnostic hypothesis to test first (per CONTEXT.md):** wrong CGS symbol signature, wrong process/window filtering, timing/permission-state assumption, or the recorded CGS symbol redeclaration collision "fix" from 66-01. **Research finding (below): the signature hypothesis is now ruled out by direct comparison; the permission-state hypothesis is now the leading candidate.**

#### Chevron placement & activation
- **D-01:** The chevron is the leftmost-positioned control item among Islet's menu-bar items — truly-hidden icons sit further left, always-visible icons stay to the right. *(unchanged)*
- **D-02:** Feature activates automatically on app launch, no Settings on/off toggle for the mechanism itself. *(unchanged)*
- **Permission gate — reopened:** Whether Islet's CGS usage needs an Accessibility permission gate (same as Ice's real app requires) is a re-opened research question. **Research finding (below): confirmed required — Ice's own source declares Accessibility `isRequired: true` and gates its entire menu-bar-management activation on it.**

#### Persistence
- **D-03:** Hidden/visible icon assignment persists across app relaunch. Given the mechanism reverts to CGS-based repositioning, whether Islet needs active re-apply logic on relaunch, or OS-level ordering persistence suffices, is back in play. **Research finding (below): Islet needs its own persisted assignment store + active re-apply logic — mirrors Ice's real, source-verified approach, not the old spacer-era research's conclusion.**

#### Reveal interaction (MENUBAR-03)
- **D-05:** Clicking the chevron reveals hidden icons inline in the menu bar itself, not a dropdown/popover. *(unchanged)*

### Claude's Discretion
- Exact persistence storage mechanism/format for D-03 — **research recommendation below: mirror Ice's model** (own persisted assignment list, keyed by a stable per-item identity; active re-apply/move on every launch — NOT reliance on the OS's own `autosaveName` position table for third-party items, which Ice itself does not rely on for this purpose).
- Chevron icon glyph/SF Symbol choice — unchanged from 66-02/66-04 (confirmed working on-device): `chevron.left`/`chevron.right`, already implemented in the still-present `MenuBarOverflowController.swift`.
- Animation style for the reveal/hide transition — none (instant), per UI-SPEC.md, matches Ice's own actual behavior.
- Whether to restore/repurpose `MenuBarOverflowBridging.swift`/`MenuBarOverflowManualSpike.swift` or start fresh — **research recommendation below: restore from git history** (commit `adfbd70` + diagnostic commits), do not start fresh; see Summary.
- Whether Islet's own status item(s) can be dragged behind the chevron — default assumption remains **exempt**, unchanged.
- Exact debugging technique — **research recommendation below: (1) real-launch vs. test-host comparison, (2) explicit Accessibility-gate check before any CGS call, (3) reinstall + relaunch real Ice as a behavioral (not byte-level) comparison reference.**

### Deferred Ideas (OUT OF SCOPE)
- Always-hidden/hotkey tier, menu-bar theming, hotkeys — out of scope per milestone MVP bound.
- Hiding Islet's own status item(s) behind the chevron — left to discretion, default exempt.
- Descoping Menübar-Overflow from v1.10 — considered and rejected.
- "Wait for stable macOS release" theory — rejected for the CGS mechanism given Ice is confirmed working on this exact build (per the user's account — see Open Questions for the one caveat this research surfaced).
- Hidden Bar's spacer technique as a fallback if CGS debugging dead-ends — not decided; return to `/gsd:discuss-phase 66` if so, don't silently fall back.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MENUBAR-01 | Chevron separates visible/hidden menu-bar icon sections | Architecture (Ice's real 2-of-3-tier `ControlItem`/`MenuBarSection` model, scoped down to Islet's 1-hide-tier MVP); chevron UI itself already built and confirmed working (`MenuBarOverflowController.swift`, 66-02/66-04) |
| MENUBAR-02 | Cmd-drag another app's icon across the chevron to hide it | Don't Hand-Roll (native OS gesture, unaffected by mechanism) + Common Pitfalls (CGS move-mechanism verification is what's actually blocked, not the drag gesture itself) |
| MENUBAR-03 | Click chevron reveals/hides; hidden icons genuinely absent | Architecture Patterns (Ice's real off-screen-reposition technique, via `MenuBarItemManager.move()`) + Common Pitfalls (occlusion-vs-reclamation must be re-confirmed on-device once enumeration itself works) |
| MENUBAR-04 | Reopened: Accessibility permission requirement, distinct explanation | Security Domain + Common Pitfalls (Permission Gate) — confirmed required by Ice's own source; existing codebase precedent (`OSDInterceptor`/`CapsLockMonitor`/`PermissionStatus.swift`) is directly reusable, UI-SPEC.md already anticipates it correctly |
</phase_requirements>

## Summary

This is a debugging phase, not a build-from-scratch phase. Plan 66-01 already built a private-CGS window-enumeration + synthetic-CGEvent-drag mechanism, transcribed directly from Ice's real source, and it NO-GO'd on-device: `CGSGetProcessMenuBarWindowList` returned exactly one, unresolvable window instead of the many real menu-bar icons visually present. CONTEXT.md's D-07 directs debugging this against real, working Ice rather than guessing at a fourth mechanism. This research fetched Ice's actual, current source directly (`github.com/jordanbaird/Ice`, MIT, `main` branch) and Islet's actual deleted spike code (recovered via `git show adfbd70`) to do a line-by-line comparison, plus checked the live machine's actual state (Ice.app's real installation status, TCC accessibility, existing codebase Accessibility-permission precedent).

**Two concrete findings reframe the debugging plan:**

**1. The "CGS symbol redeclaration collision" fix is verified NOT to be the bug.** 66-01-SUMMARY.md flagged the collision fix (reusing the codebase's existing `CGSMainConnectionID() -> Int32` instead of re-declaring `CGSConnectionID`) as the prime suspect for a subtle divergence. Direct comparison against Ice's real `Ice/Bridging/Shims/Private.swift` (fetched live) shows Islet's fixed declarations for all three symbols the spike calls (`CGSGetWindowCount`, `CGSGetProcessMenuBarWindowList`, `CGSGetScreenRectForWindow`) are **byte-for-byte identical in parameter order and type** to Ice's own (`CGSConnectionID` is itself `typealias CGSConnectionID = Int32` in Ice's real source — the exact same underlying type Islet's fix settled on independently). `[VERIFIED: github.com/jordanbaird/Ice, Ice/Bridging/Shims/Private.swift, fetched directly this session]`. The redeclaration-collision fix is exonerated; the divergence is elsewhere.

**2. The leading new hypothesis is a missing/unverified Accessibility-permission gate.** Ice's real `Ice/Permissions/Permission.swift` declares `AccessibilityPermission` with `isRequired: true`, and `PermissionsManager.swift` gates Ice's *entire* menu-bar-management activation on `requiredPermissions.allSatisfy({ $0.hasPermission })` — i.e., **Ice does not even attempt CGS enumeration/movement until Accessibility is confirmed trusted** `[VERIFIED: github.com/jordanbaird/Ice, Ice/Permissions/Permission.swift + PermissionsManager.swift, fetched directly this session]`. Islet's deleted 66-01 spike, by contrast, only *printed* `AXIsProcessTrusted()` as a diagnostic — it never gated or branched on the result, and 66-01-SUMMARY.md never records what that printed value actually was. A near-empty, single-unresolvable-window CGS result is exactly the symptom an untrusted-for-Accessibility calling process would plausibly produce (undocumented private WindowServer behavior, but consistent with Ice's own design assuming it matters). This is the single most actionable, cheapest thing to check first on-device — cheaper than any Ice-vs-Islet diffing.

**A related, second-order hypothesis:** the spike ran via Xcode's `Cmd-U` inside an app-hosted XCTest bundle (`TEST_HOST = Islet.app/Contents/MacOS/Islet`, confirmed in `project.yml`). `Bundle.main.bundleIdentifier` correctly resolves to `com.lippi304.islet` in this configuration (already confirmed in 66-01 Round 3), so this is not the classic "wrong bundle identity" gotcha — but the process is still *launched* via the XCTest harness (`posix_spawn`/`xctest`), not via a normal LaunchServices `open`/double-click launch the way the user actually runs Ice daily. Whether WindowServer/CGS treats a test-hosted launch identically to a real app launch for cross-process menu-bar enumeration purposes is untested and worth ruling out cheaply (see Architecture Patterns, Debugging Methodology).

**Third finding — Ice.app is not currently present on disk.** The Homebrepresent Homebrew cask receipt (`jordanbaird-ice`, v0.11.12) is intact, but `/opt/homebrew/Caskroom/jordanbaird-ice/0.11.12/Ice.app` is a **dangling symlink** to `/Applications/Ice.app`, which does not exist. CONTEXT.md's "installed but not currently running" assumption is only half right — Ice needs to be **reinstalled** (`brew reinstall --cask jordanbaird-ice`), not just launched, before it can serve as a live comparison reference. This is a Wave-0 blocker for the debugging plan `[VERIFIED: this session, live filesystem check]`.

**Fourth finding — Ice's real persistence model directly answers D-03.** Ice's `StatusItemDefaults.swift` reads/writes the OS's own private `"NSStatusItem Preferred Position <autosaveName>"` UserDefaults keys — but this only works for items **Ice itself owns** (its own 3 control items' UserDefaults domain). For *other apps'* menu-bar items, Ice has no cross-process write access to their private defaults domain, so their hidden/visible section membership cannot be persisted via the OS's `autosaveName` mechanism at all — Ice must (and does, architecturally, via its own `MenuBarSection`/`MenuBarItemManager` model) track a separate, Ice-owned mapping of third-party item identity → section, and **actively re-apply (re-move) that assignment on every launch**. This directly resolves D-03 in favor of "Islet needs its own persisted assignment store + active re-apply logic," reopening exactly the possibility CONTEXT.md flagged and contradicting the now-superseded spacer-era research's Pitfall 1 conclusion (which only ever applied to the abandoned spacer mechanism).

**Primary recommendation:** Restore `MenuBarOverflowBridging.swift`/`MenuBarOverflowManualSpike.swift` from git history (`git show adfbd70`) rather than starting fresh — the shim's CGS signatures are verified correct against Ice's real source, so there is no known correctness bug to redesign around. The debugging plan should, in order: (1) reinstall Ice.app and confirm it still genuinely works today (re-validate the user's account, since the binary was found missing), (2) add an explicit Accessibility-permission gate + prompt (mirroring the codebase's existing `OSDInterceptor.isAccessibilityTrusted`/`CapsLockMonitor` pattern) in front of the restored CGS calls, not just a diagnostic print, (3) re-run the exact same enumeration code from a **real app launch** (not `Cmd-U`) via a temporary debug-menu action (reusing the existing `debugStatusItem` debug-menu pattern), to rule out the test-host-launch hypothesis independently of the permission hypothesis, (4) only pursue deeper Ice-internals comparison if both of the above still fail to explain the divergence.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Private CGS window enumeration (find other apps' menu-bar-item windows) | App process, isolated shim file (`MenuBarOverflowBridging.swift`, restored) | macOS WindowServer/CGS (out-of-process, undocumented behavior) | Mirrors this codebase's "isolate the fragile/uncertain thing behind its own seam" precedent (`NowPlayingMonitor`/`MicMuteController`/`MeetingMonitor`); the app never owns correctness of the private mechanism, only calls it defensively |
| Accessibility permission check + gate | App process (new gate, mirrors `OSDInterceptor.isAccessibilityTrusted`/`CapsLockMonitor`) | Settings UI (SwiftUI, new row per UI-SPEC.md) | Ice's own source proves this gate is load-bearing, not optional — must run BEFORE any CGS call, not just be logged |
| Synthetic CGEvent drag (move a real menu-bar item) | App process, isolated shim file | macOS WindowServer/CGS + the target app's own status-item event handling (out-of-process) | Same fragile-surface isolation; this half of the mechanism is unverified but structurally sound (byte-parity with Ice's `MenuBarItemManager` shape) — retest only after enumeration itself is proven |
| Hidden/visible assignment persistence (D-03) | App process, new dedicated store (UserDefaults, keyed by stable third-party item identity) | — (NOT the OS's `autosaveName` table — confirmed inapplicable to third-party items) | Ice's own `StatusItemDefaults` mechanism only reaches items Ice itself owns; the same constraint applies to Islet — this is genuinely new, necessary code, not something to skip |
| Chevron UI (icon, click toggle, glyph swap) | App process, `MenuBarOverflowController.swift` (already built, 66-02) | — | Confirmed working on-device in 66-04's UAT; reuse as-is, only replace its internal state-application call (spacer `.length` toggle -> CGS move) |
| Accessibility permission UI (popover, Settings row) | SwiftUI (`SettingsView.swift`, extending existing `permissionsSection`) | App process (`AXIsProcessTrusted()` read) | UI-SPEC.md already specifies this fully and correctly, reusing `osdPermissionExplanationView`/`capsLockPermissionExplanationView`'s exact shape — a proven, shipped pattern in this codebase |

## Standard Stack

No new external package dependency — this phase is 100% Apple system frameworks (AppKit, CoreGraphics/private CGS symbols already used elsewhere in this codebase) plus restoring previously-written, previously-verified-to-build Swift source from git history.

### Core

| Approach | Purpose | Why Standard (for this exact problem) |
|----------|---------|----------------------------------------|
| `@_silgen_name`-bound private `CGS*` symbols (`CGSGetWindowCount`, `CGSGetProcessMenuBarWindowList`, `CGSGetScreenRectForWindow`) | Window enumeration + frame reads | `[VERIFIED: github.com/jordanbaird/Ice, Ice/Bridging/Shims/Private.swift, fetched directly this session]` — signatures confirmed byte-for-byte identical to Ice's real, current declarations; already proven to compile clean in this codebase (commit `adfbd70`) |
| `CGEvent.postToPid(_:)` for synthetic Cmd-drag | Moving a real third-party menu-bar item | `[CITED: codebase, 66-01-SUMMARY.md key-decisions]` — a real, documented public `CGEvent` API, deliberately used instead of porting Ice's fuller `EventTap`/`scrombleEvent` routing; sufficient to validate the mechanism |
| `AXIsProcessTrusted()` / `AXIsProcessTrustedWithOptions(prompt:)` | Accessibility permission check/request gate | `[VERIFIED: codebase]` — already used identically for the same permission bucket by `OSDInterceptor.isAccessibilityTrusted`, `CapsLockMonitor.isAccessibilityTrusted`, `DropInterceptTap.swift` |
| `CGWindowListCopyWindowInfo` (public) | Owner-PID resolution for a CGS windowID; independent cross-check | `[VERIFIED: codebase]` — already used in the restored spike (`windowOwnerPIDs()`) and in the 66-01 diagnostic commit `68bb5a2`'s independent statusWindow-layer cross-check |
| `UserDefaults`, keyed by a stable per-item identity | Persisted hidden/visible assignment for third-party items (D-03) | `[CITED: github.com/jordanbaird/Ice, Ice/Utilities/StatusItemDefaults.swift + MenuBarItemInfo.swift, fetched directly]` — Ice's own model requires an app-owned mapping for items it doesn't control the `autosaveName` domain of; mirror the *shape* (a stable `namespace:title`-like identity), not the literal private `"NSStatusItem ..."` key format (that format only works for self-owned items) |
| `NSStatusBar.system.statusItem(withLength:)`, `.autosaveName` | Chevron construction | `[VERIFIED: codebase]` — already built and confirmed working on-device, `MenuBarOverflowController.swift` (66-02) |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Existing `PermissionStatus.swift`/`PermissionKind` 3-state model | This codebase (Phase 54) | Not extended to a 6th `PermissionKind` case per UI-SPEC.md's explicit instruction — Accessibility for this feature reuses the OSD/CapsLock bespoke-row pattern instead, since Accessibility already has its own rollup-external handling elsewhere | Read-only reference; do not add Menübar-Overflow as a `PermissionKind` case |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Restoring 66-01's deleted spike files from git history | Writing the CGS shim fresh, informed by "lessons learned" | `[Research judgment]` — nothing found in this session invalidates the shim's own correctness (signature-verified against Ice); rewriting from scratch discards a working, build-clean, byte-parity-verified artifact to solve a bug that is very likely a *missing gate*, not a *wrong shim*. Restore, then add the gate. |
| A stable per-item `MenuBarItemInfo`-style identity (bundle ID + item/window title) for D-03's persisted store | Bundle ID alone | `[CITED: github.com/jordanbaird/Ice, MenuBarItemInfo.swift]` — Ice's own identity model is `namespace + title`, not bundle ID alone, because some apps host multiple distinct menu-bar items; bundle-ID-only risks conflating them for apps with >1 status item. Follow Ice's shape unless a concrete Islet-specific reason emerges to simplify further (this project's MVP may only need bundle-ID granularity if the user's real menu bar has at most one item per app — worth a quick on-device check, not a blocking assumption). |

**Installation:** No package manager changes. Restoring deleted files: `git show adfbd70:Islet/Notch/MenuBarOverflowBridging.swift` / `git show adfbd70:IsletTests/MenuBarOverflowManualSpike.swift`, reapplying diagnostic commits `5f231f3`/`6136d7f`/`68bb5a2` if their prints are still wanted, then `xcodegen generate` to re-register the files (removed from `project.pbxproj` by 66-03).

**Version verification:** N/A — no versioned package added. Ice's source was fetched from its `main` branch (ahead of or equal to the installed cask version 0.11.12, tagged 2024-10-29 — the `main` branch may include later, unreleased commits, but the CGS shim / permission-gating architecture examined here is foundational and very unlikely to have changed; if a future debugging step finds a discrepancy against the actually-installed binary's behavior, re-check against the `v0.11.12` tag specifically rather than `main`).

## Package Legitimacy Audit

Not applicable — no new external package dependency. All code is Apple system frameworks plus restored, previously-committed internal Swift source.

**Packages removed due to slopcheck verdict:** none (no packages proposed).
**Packages flagged as suspicious:** none.

## Architecture Patterns

### System Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│  macOS WindowServer / CGS (out-of-process, undocumented behavior)        │
│                                                                            │
│  Real Ice.app (once reinstalled + relaunched)                            │
│    Permission.swift: AccessibilityPermission.isRequired = true            │
│    PermissionsManager: gates ALL menu-bar mgmt on hasPermission ──┐        │
│                                                                    │        │
│    Bridging.getMenuBarWindowList() ◄── CGSGetProcessMenuBarWindowList     │
│      (only reached once Accessibility is confirmed trusted)      │        │
│    MenuBarItemManager.move() ◄── synthetic CGEvent drag           │        │
│    StatusItemDefaults ◄── writes Ice's OWN control items' OS      │        │
│      "NSStatusItem Preferred Position <autosaveName>" keys        │        │
│      (third-party items: Ice tracks section membership itself,    │        │
│       re-applies via move() on every launch — NOT OS autosave)    │        │
└───────────────────────────▲────────────────────────────────────────┘
                             │ SAME private CGS symbols, SAME connection API
                             │ (signature-verified identical, this session)
┌────────────────────────────┴──────────────────────────────────────────┐
│  Islet app process                                                      │
│                                                                          │
│  [STEP 0 — Wave 0] Reinstall Ice.app (currently a dangling symlink,     │
│      not actually present on disk) — blocks live comparison entirely   │
│                                                                          │
│  [STEP 1] AXIsProcessTrusted() gate — NEW, was missing in 66-01's       │
│      deleted spike (only logged, never branched on) ──► if false:      │
│      show permission popover (UI-SPEC.md), chevron absent, STOP here   │
│                                                                          │
│  [STEP 2] Restored MenuBarOverflowBridging.menuBarItemWindows()         │
│      (git show adfbd70 — signature-verified against Ice's real         │
│      Private.swift, byte-for-byte) — re-run ONLY after Step 1 passes   │
│                                                                          │
│  [STEP 3] Compare: real-launch (open Islet.app) vs. Cmd-U test-host     │
│      launch — same enumeration code, two launch paths, log both        │
│                                                                          │
│  [STEP 4] Restored moveMenuBarItem() (CGEvent.postToPid synthetic       │
│      Cmd-drag) — retest only once Step 2/3 confirm real enumeration    │
│                                                                          │
│  [STEP 5] NEW: persisted third-party item assignment store (D-03) —    │
│      UserDefaults, keyed by stable item identity, active re-apply on   │
│      every launch (mirrors Ice's real architecture, not OS autosave)   │
│                                                                          │
│  MenuBarOverflowController.swift (66-02, UNCHANGED chevron/glyph/click) │
│      ──internal state-application swapped from spacer.length toggle──► │
│      to Step 2/4's CGS move calls                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure

```
Islet/Notch/
├── MenuBarOverflowBridging.swift        # RESTORE from git show adfbd70 — CGS shim, signature-verified against Ice's real source, no known bug
├── MenuBarOverflowController.swift      # KEEP (66-02) — chevron UI/glyph-swap unchanged; swap internal mechanism call only
├── MenuBarOverflowAssignmentStore.swift # NEW — D-03's persisted third-party hidden/visible assignment (mirrors Ice's own-item-vs-third-party-item split)
IsletTests/
├── MenuBarOverflowManualSpike.swift     # RESTORE from git show adfbd70 — add the Accessibility gate check to its printed diagnostics
├── MenuBarOverflowClampTests.swift      # REMOVE or repurpose — clampedExpandedSpacerLength() has no role under the CGS mechanism (no spacer, no screen-width clamp)
```

### Pattern 1: Debugging methodology — cheapest-first elimination order

**What:** Before any Ice-vs-Islet source diffing, eliminate the two candidate causes this research found evidence for, in cheapest-first order.

**When to use:** First task of the debugging plan, before restoring/modifying any production mechanism code.

**Steps, in order:**
1. **Reinstall Ice** (`brew reinstall --cask jordanbaird-ice`), launch it, confirm on-device that it still genuinely hides/shows real icons today — re-validating the user's account now that the binary was found missing from disk. If this step itself fails, the entire premise of D-07 needs to return to discussion.
2. **Restore the 66-01 spike** (`git show adfbd70:...` both files, `xcodegen generate`), but before re-running its `menuBarItemWindows()` call, insert an explicit `guard AXIsProcessTrusted() else { print("NOT TRUSTED — this fully explains a near-empty CGS result"); return }` at the top of the spike's test function — not just a log line. Run once with Accessibility deliberately NOT granted (fresh state or via `tccutil reset Accessibility com.lippi304.islet`) and once after explicitly granting it in System Settings, comparing the enumeration result between the two runs.
3. **Test real-launch vs. test-host-launch**, independent of Step 2: add a temporary debug-menu action (reusing the existing `debugStatusItem` debug-menu construction pattern at `AppDelegate.swift` ~490+) that calls the exact same `menuBarItemWindows()` function, then compare its printed output between (a) a genuine `open /path/to/Islet.app` launch and (b) a `Cmd-U` test-hosted launch, with Accessibility trust held constant across both.
4. Only if both Step 2 and Step 3 fail to explain the divergence: proceed to deeper comparison (see Pattern 2).

**Why this order:** Step 2 is a one-line code change with a binary, unambiguous on-device result. Step 3 requires no new understanding of Ice's internals at all. Both are cheaper and more conclusive than any form of live process diffing, and both map directly to concrete, source-backed evidence this research already surfaced.

### Pattern 2: If Pattern 1 doesn't resolve it — behavioral (not byte-level) comparison against real Ice

**What:** `lsappinfo` does not expose CGS-level menu-bar window lists — it is a process-info tool, not a window-server introspection tool `[Research note: verified by omission — no CGS/menu-bar-specific output documented for `lsappinfo`, and this session found no evidence it exposes this data; do not assume it does]`. The practical "private tooling" equivalent already exists in this codebase: the public `CGWindowListCopyWindowInfo` cross-check added in diagnostic commit `68bb5a2`. Use that, not `lsappinfo`, for any live inspection.

**When to use:** Only after Pattern 1's two hypotheses are both ruled out on-device.

**Technique:** With real Ice running (reinstalled, Accessibility granted, actively hiding/showing icons the user can watch), run Islet's restored `menuBarItemWindows()` (with Islet's OWN Accessibility now also granted) and compare the returned bundle-ID set against what is visually present in the menu bar at that moment. This is a behavioral comparison (does Islet's enumeration see what a human sees), not a byte-level diff of two processes' internal state — CGS enumeration is inherently scoped to the calling process's own connection, so there is no meaningful way to "diff Ice's raw CGS output" from outside Ice's own process without building a second private tool that itself needs the identical permission/launch-context questions Pattern 1 addresses for Islet.

### Pattern 3: Ice's real persistence architecture (resolves D-03)

**What:** Ice's `StatusItemDefaults` enum (`Ice/Utilities/StatusItemDefaults.swift`) is a typed proxy over `UserDefaults.standard`, using the exact string-key format macOS's own `NSStatusItem.autosaveName` mechanism uses internally (`"NSStatusItem Preferred Position <autosaveName>"`, `"NSStatusItem Visible <autosaveName>"`). Ice uses this **only for its own three control items** (whose `autosaveName`/UserDefaults domain it owns). For third-party items, Ice cannot write into another app's private defaults domain — so their section (hidden/visible) membership must be tracked in Ice's own storage and **actively re-applied** (re-moved via the same CGEvent mechanism) on every relaunch.

**When to use:** Directly informs Islet's D-03 implementation. Build a small, Islet-owned `UserDefaults`-backed store keyed by a stable per-item identity (see Standard Stack's `MenuBarItemInfo`-shape recommendation), plus an active re-apply pass (re-issue the CGS move for every persisted "hidden" item) at app launch, after the Accessibility gate passes.

**Example (identity shape, adapted from Ice's real source):**
```swift
// Source: github.com/jordanbaird/Ice, Ice/MenuBar/MenuBarItems/MenuBarItemInfo.swift (fetched directly)
// Ice's real identity model — namespace + title, not bundle ID alone:
struct MenuBarItemInfo: Hashable, CustomStringConvertible {
    let namespace: Namespace   // e.g. the owning bundle identifier
    let title: String         // the item's own title/identifier string
}
```

```swift
// Source: github.com/jordanbaird/Ice, Ice/Utilities/StatusItemDefaults.swift (fetched directly)
// Ice's real persistence proxy — direct manipulation of the OS's own private key format,
// but ONLY reachable for items Ice itself owns:
enum StatusItemDefaults {
    static subscript<Value>(key: Key<Value>, autosaveName: String) -> Value? {
        get { UserDefaults.standard.object(forKey: key.stringKey(for: autosaveName)) as? Value }
        set { UserDefaults.standard.set(newValue, forKey: key.stringKey(for: autosaveName)) }
    }
}
// For THIRD-PARTY items (no writable autosaveName domain), Islet needs its OWN separate
// UserDefaults store (bundle ID/title -> hidden Bool) + active re-apply on launch — this is
# the part of D-03 that is genuinely new work, not something the OS does automatically.
```

### Pattern 4: Ice's real permission-gating shape (resolves MENUBAR-04's technical feasibility question)

**What:** Ice's `AccessibilityPermission` (`Ice/Permissions/Permission.swift`) wraps `checkIsProcessTrusted()`/`checkIsProcessTrusted(prompt: true)` (Ice's own thin wrapper, not shown directly in this file, but functionally equivalent to `AXIsProcessTrusted()`/`AXIsProcessTrustedWithOptions(prompt:)`) and is declared `isRequired: true`. `PermissionsManager` observes all permissions' `$hasPermission` publishers and only allows full menu-bar management once `requiredPermissions.allSatisfy({ $0.hasPermission })`.

**When to use:** Confirms MENUBAR-04's technical premise is sound and matches this codebase's own established pattern exactly (`OSDInterceptor.isAccessibilityTrusted`, `CapsLockMonitor.isAccessibilityTrusted` — both a plain `AXIsProcessTrusted()` computed property, gating a feature's activation). UI-SPEC.md's already-written contract (one-time popover, Settings row reusing `permissionRow`'s shape, deep-link to `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`) needs no revision — it is consistent with Ice's real requirement and this codebase's existing precedent.

**Example (existing codebase pattern to clone, not Ice's — this one's already proven in production here):**
```swift
// Source: Islet/Notch/OSDInterceptor.swift:46 (this codebase, existing pattern)
static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }
```

### Anti-Patterns to Avoid

- **Treating `AXIsProcessTrusted()` as a diagnostic print instead of a gate.** This is the exact gap identified in the deleted 66-01 spike — printing the value without branching on it before the CGS calls masks exactly the failure mode this research now suspects caused the NO-GO.
- **Assuming `lsappinfo` exposes CGS menu-bar window state.** No evidence found for this; do not build tooling around an unverified capability (see Pattern 2).
- **Relying on `NSStatusItem.autosaveName`/OS-level position persistence for THIRD-PARTY items' hidden/visible assignment.** Confirmed inapplicable — even Ice, which owns the reference implementation, does not do this for other apps' items (Pattern 3). This directly overturns the now-superseded spacer-era research's Pitfall 1 conclusion, which only ever applied to that abandoned mechanism.
- **Re-declaring `CGSConnectionID`/`CGSMainConnectionID` a second time in the restored shim.** The existing fix (reuse the codebase's global `CGSMainConnectionID() -> Int32`, type new symbols' connection-ID params as raw `Int32`) is verified correct and must be kept as-is when restoring — do not "fix" something that direct comparison shows was never broken.
- **Rebuilding the CGS shim from scratch "to be safe."** Given the byte-for-byte signature verification in this research, this would be solving a problem that (per current evidence) doesn't exist, at the cost of re-deriving already-correct, already-build-verified code.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cmd-drag repositioning gesture | Custom `NSDraggingSession`/drop-target code | Nothing — native macOS behavior for any `NSStatusItem` | Unaffected by which technique owns the separator; confirmed in both Ice's and Islet's own prior 66-04 UAT (the gesture itself was never the point of failure — the underlying mechanism was) |
| Accessibility permission check plumbing | A new bespoke permission-check abstraction | `AXIsProcessTrusted()`/`AXIsProcessTrustedWithOptions(prompt:)`, mirroring `OSDInterceptor.isAccessibilityTrusted`/`CapsLockMonitor.isAccessibilityTrusted` verbatim | Already proven, shipped, working in this exact codebase for the identical permission bucket — do not reinvent |
| CGS symbol declarations | Re-deriving symbol signatures from scratch or from memory | The restored, git-history-preserved `MenuBarOverflowBridging.swift`, now signature-verified against Ice's real current source | Already correct; re-deriving risks reintroducing a genuine bug where none currently exists |
| lsappinfo-style live introspection tooling | A custom CLI tool wrapping private WindowServer APIs | The existing public `CGWindowListCopyWindowInfo` cross-check already built into the 66-01 diagnostics (commit `68bb5a2`) | Already exists, already proven useful (it's what found the real Islet status item the private CGS call missed), no need to build new tooling |

**Key insight:** Nearly everything genuinely reusable for this phase already exists — either in the live codebase (`MenuBarOverflowController.swift`'s chevron UI, the existing Accessibility-permission pattern) or in git history (the CGS shim, now verified correct). The actual new work is narrow: an explicit permission gate (was a print, must become a guard), a real-launch verification (was untested), and a persisted third-party-item assignment store (D-03, genuinely new).

## Common Pitfalls

### Pitfall 1: Permission Gate — treating the Accessibility check as informational instead of load-bearing

**What goes wrong:** Calling any `CGS*` menu-bar enumeration/movement function without first confirming `AXIsProcessTrusted()` is `true`, and without gating the feature's entire activation on it (mirroring Ice's `PermissionsManager` behavior).

**Why it happens:** The deleted 66-01 spike already made exactly this mistake — it logged the value but never used it as a guard. `[VERIFIED: github.com/jordanbaird/Ice, Permission.swift/PermissionsManager.swift]` confirms Ice's own real app treats Accessibility as a hard precondition, not an informational check.

**How to avoid:** Add an explicit `guard AXIsProcessTrusted() else { ... ; return }` (or equivalent early-return) before any CGS call in both the restored production controller and the restored manual spike. Wire the UI-SPEC.md-specified permission popover/Settings-row gate so the chevron itself is never even constructed while untrusted (already specified, just needs implementing against the restored mechanism instead of the abandoned spacer one).

**Warning signs:** A near-empty or single-unresolvable-window CGS enumeration result — this is the exact signature 66-01 already observed once, under exactly this untested condition.

### Pitfall 2: Launch-context assumption — Cmd-U test-hosted process treated as equivalent to a real app launch

**What goes wrong:** Assuming a hosted-XCTest run (`Cmd-U`) is a faithful stand-in for how the user actually runs the app (`open`/double-click/LaunchAgent), for purposes of cross-process WindowServer/CGS behavior specifically.

**Why it happens:** `Bundle.main.bundleIdentifier` correctly resolving to `com.lippi304.islet` under the `TEST_HOST`-hosted configuration (confirmed, `project.yml`) creates a false sense that the process context is fully equivalent — it rules out the *bundle-identity* gotcha but says nothing about the *launch-path* (LaunchServices `open` vs. `posix_spawn`-by-xctest) or *WindowServer session attachment* differences, which are untested in this project.

**How to avoid:** Before concluding anything about Ice-vs-Islet mechanism divergence, run the identical enumeration code from a genuine `open`-launched instance (a temporary debug-menu action is sufficient — reuses the existing `debugStatusItem` debug-menu construction already in `AppDelegate.swift`) and compare against the `Cmd-U` result, with Accessibility trust held constant.

**Warning signs:** Enumeration succeeds from a real launch but not from `Cmd-U` (or vice versa) — this alone would fully explain 66-01's NO-GO without any mechanism bug at all.

### Pitfall 3: D-03 persistence — assuming OS-level `autosaveName` persistence covers third-party items

**What goes wrong:** Building Islet's persistence around `NSStatusItem.autosaveName`/the OS's own position table for OTHER apps' icons, the way the now-superseded spacer-era research recommended for that (different, abandoned) mechanism.

**Why it happens:** `autosaveName`-based persistence is real and does work — but only for status items whose OWNING PROCESS sets it, writing into that process's own UserDefaults domain. Islet cannot set `autosaveName` (or write the corresponding UserDefaults key) for an app it doesn't own. `[CITED: github.com/jordanbaird/Ice, StatusItemDefaults.swift + MenuBarSection.swift architecture, fetched directly]` — even Ice, the reference implementation, does not rely on this for third-party items.

**How to avoid:** Build a small, Islet-owned `UserDefaults` store (bundle ID/title-keyed) tracking which third-party items are assigned hidden vs. visible, and actively re-apply (re-issue the CGS move) for every persisted-hidden item at each app launch, after the Accessibility gate passes. This is real, necessary implementation work for this phase — do not scope it out as "OS handles it."

**Warning signs:** A third-party icon's hidden/visible state reverting to default (visible) after every relaunch, even though the user explicitly hid it in the prior session.

### Pitfall 4: Ice.app's real on-disk presence — do not assume "installed" means "launchable"

**What goes wrong:** Proceeding straight to "launch Ice for comparison" (as CONTEXT.md's debugging plan assumes) without first confirming the binary is actually present.

**Why it happens:** `brew list --cask jordanbaird-ice` and the cask receipt both report Ice as installed, and the user's own account states it currently works as their daily driver — but this session found `/opt/homebrew/Caskroom/jordanbaird-ice/0.11.12/Ice.app` is a **dangling symlink** to `/Applications/Ice.app`, which does not currently exist on disk. `[VERIFIED: this session, live filesystem check]`.

**How to avoid:** Treat "reinstall Ice" (`brew reinstall --cask jordanbaird-ice`) as an explicit Wave-0 step, not an assumed no-op. After reinstalling, re-confirm on-device that Ice still genuinely hides/shows real icons today, since the user's account of "it works" may predate whatever removed the app bundle from `/Applications`.

**Warning signs:** `open /Applications/Ice.app` or `open -a Ice` failing with "application not found."

### Pitfall 5: Move-mechanism verification order — don't retest the drag before enumeration is proven

**What goes wrong:** Jumping straight to re-testing `moveMenuBarItem()`/the synthetic-CGEvent-drag half of the restored spike before confirming enumeration itself now works.

**Why it happens:** Both halves of the mechanism were built and committed together in Plan 66-01, but only enumeration was ever actually exercised on-device (the NO-GO happened at the enumeration step; the move function was never reached). It remains unverified but structurally sound (byte-parity with Ice's `MenuBarItemManager.move()`/`wakeUpItem()` shape).

**How to avoid:** Sequence the debugging plan so enumeration is confirmed working (Pattern 1) before spending any effort re-verifying or debugging the move/drag half — if enumeration was the whole problem, the move code may well work unmodified on first real attempt.

**Warning signs:** None yet observed — this is a sequencing risk, not an observed symptom.

## Code Examples

### Existing codebase pattern for the Accessibility gate (clone this, not something new)

```swift
// Source: Islet/Notch/OSDInterceptor.swift:46 (this codebase, existing, shipped pattern)
static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }
```

### Ice's real CGS shim declarations (verified byte-for-byte match against Islet's restored, fixed shim)

```swift
// Source: github.com/jordanbaird/Ice, Ice/Bridging/Shims/Private.swift (fetched directly, this session)
typealias CGSConnectionID = Int32   // matches Islet's own post-fix raw Int32 usage exactly

@_silgen_name("CGSGetProcessMenuBarWindowList")
func CGSGetProcessMenuBarWindowList(
    _ cid: CGSConnectionID,
    _ targetCID: CGSConnectionID,
    _ count: Int32,
    _ list: UnsafeMutablePointer<CGWindowID>,
    _ outCount: inout Int32
) -> CGError
```

### Ice's real permission-gating shape (confirms MENUBAR-04's necessity)

```swift
// Source: github.com/jordanbaird/Ice, Ice/Permissions/Permission.swift (fetched directly, this session)
final class AccessibilityPermission: Permission {
    init() {
        super.init(
            title: "Accessibility",
            details: [
                "Get real-time information about the menu bar.",
                "Arrange menu bar items.",
            ],
            isRequired: true,   // <- gates ALL menu-bar management, not optional
            settingsURL: nil,
            check: { checkIsProcessTrusted() },
            request: { checkIsProcessTrusted(prompt: true) }
        )
    }
}
```

### Restoring the deleted spike (exact command)

```bash
git show adfbd70:Islet/Notch/MenuBarOverflowBridging.swift > Islet/Notch/MenuBarOverflowBridging.swift
git show adfbd70:IsletTests/MenuBarOverflowManualSpike.swift > IsletTests/MenuBarOverflowManualSpike.swift
# Optionally reapply the diagnostic prints from 5f231f3/6136d7f/68bb5a2 if still wanted.
xcodegen generate   # re-register both files, removed from project.pbxproj by 66-03
```

## State of the Art

| Old Approach (this phase's own prior revisions) | Current Approach | When Changed | Impact |
|--------------------------------------------------|-------------------|---------------|--------|
| Ice-mechanism spike with an unverified, print-only Accessibility check (Plan 66-01) | Same mechanism, restored, with an explicit gate + real-launch verification before any further mechanism debugging | This revision (2026-07-28), following the second discussion pivot (D-07) | Reframes the NO-GO from "the mechanism is broken" to "the mechanism was likely never given a fair test" — a materially cheaper and more optimistic starting point than either prior revision assumed |
| Public spacer-`NSStatusItem` technique (Plan 66-02/66-04, D-06) | Abandoned — NO-GO'd on-device, Cmd-drag never engaged with the spacer and `.length` toggle had zero layout effect | Plan 66-04's on-device UAT (2026-07-28) | Confirms the old spacer-era research's core assumption (public API = automatically lower risk) does not always hold; do not resurrect without new on-device evidence |

**Deprecated/outdated:** The spacer-era research (2026-07-27 revision, now fully superseded) remains historically accurate for what it described but must not inform any part of this phase going forward — its Pitfall 1 (autosave-based persistence sufficiency) explicitly does not transfer to the CGS mechanism (see Pitfall 3 above).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The near-empty/single-unresolvable-window CGS enumeration result observed in 66-01 was caused by an unconfirmed/absent Accessibility trust state, not a genuine mechanism bug | Summary, Pitfall 1 | If wrong, the debugging plan's cheapest-first step (Pattern 1, Step 2) will fail to resolve the NO-GO and the plan must fall through to Pattern 2's deeper comparison — low cost to test, so low risk even if wrong |
| A2 | Ice's real source on the `main` branch (fetched this session) accurately represents the mechanism the installed v0.11.12 cask binary actually runs, despite `main` potentially being ahead of the 2024-10-29-tagged release | Standard Stack, Summary | If `main` has since materially changed the CGS shim or permission-gating shape, the "verified byte-for-byte match" claim would need re-confirming against the `v0.11.12` tag specifically — low probability given this is foundational, rarely-touched code, but not zero |
| A3 | A hosted-XCTest (`Cmd-U`) launch context could plausibly behave differently from a real LaunchServices-launched instance for cross-process CGS menu-bar enumeration specifically | Pitfall 2 | If wrong (i.e., launch context genuinely makes no difference), Pattern 1 Step 3 will simply confirm no difference and can be skipped in future debugging — cheap to test, low risk either way |
| A4 | Ice's own third-party-item persistence is a separately-tracked, Ice-owned mapping with active re-apply on launch, rather than something this research found stated explicitly in one single confirming line of source | Pitfall 3, Pattern 3 | Inferred from `StatusItemDefaults`' scope (own-items-only) plus `MenuBarSection`'s section-membership model, not from one explicit "here's the third-party persistence code" function this session directly read line-by-line; if wrong in some detail, the *architectural conclusion* (need an Islet-owned store) still holds regardless, since Islet cannot write another app's UserDefaults domain either way — the risk is only in the exact shape (identity key format), not the core recommendation |
| A5 | `lsappinfo` does not expose CGS-level menu-bar window/enumeration data | Pattern 2, Anti-Patterns | This is a claim of absence based on this session finding no documentation or evidence for the capability, not an exhaustive audit of every `lsappinfo` subcommand — if wrong, it would only mean a *nice-to-have* diagnostic tool exists that wasn't used, not that any recommendation above is incorrect |

**If this table is empty:** N/A — see entries above. None of A1-A5 block planning; each is cheap to test on-device and the debugging plan (Pattern 1) is explicitly sequenced to surface a wrong assumption quickly and cheaply rather than requiring it to be resolved up front.

## Open Questions (RESOLVED)

1. **Was Accessibility actually trusted for `com.lippi304.islet` at the exact moment of Plan 66-01's on-device NO-GO?**
   - What we know: The spike printed `AXIsProcessTrusted()` but 66-01-SUMMARY.md never records the printed value; TCC.db is not readable from this research session (protected, requires Full Disk Access) to check retroactively.
   - What's unclear: Whether the answer is recoverable at all (if the console log from that Cmd-U session wasn't saved) or must be re-tested fresh.
   - Recommendation: Don't try to reconstruct the past — just re-test cleanly per Pattern 1, Step 2, with the state deliberately controlled (`tccutil reset Accessibility com.lippi304.islet` then re-grant) so the answer is unambiguous going forward.
   - → **Resolved by 66-05-PLAN.md Task 2** (on-device Pattern 1 elimination checkpoint, Steps 1-4 deliberately control and re-test the trust state fresh rather than reconstructing the past).

2. **Does the user's account of "Ice currently works on this machine" still hold, given Ice.app was found missing from `/Applications`?**
   - What we know: The Homebrew cask receipt is intact (installed 2026-04-13) and the user's account (2026-07-28 discussion) describes daily use, but the actual `.app` bundle is not present now — only a dangling Caskroom symlink.
   - What's unclear: Whether the app was recently removed (e.g., during disk cleanup) after the user's account was given, or whether the user's mental model of "installed" was already inaccurate at discussion time.
   - Recommendation: Reinstall (`brew reinstall --cask jordanbaird-ice`) as Wave 0, then have the user directly re-confirm real Ice hides/shows icons today, before investing further debugging effort on the assumption that a working reference definitely exists on this exact machine right now.
   - → **Resolved by 66-05-PLAN.md Task 1** (reinstalls Ice via `brew reinstall --cask jordanbaird-ice` as the first Wave-0 action, before any spike restoration work).

3. **What is the correct stable identity key for D-03's persisted third-party assignment — bundle ID alone, or Ice's fuller `namespace + title` shape?**
   - What we know: Ice uses `namespace + title` because some single apps expose more than one distinct menu-bar item.
   - What's unclear: Whether any app in this user's actual menu bar has more than one status item (if not, bundle-ID-only is suffient and simpler for this MVP).
   - Recommendation: Cheap to check during the same on-device session that validates enumeration (Pattern 1) — log each enumerated item's owning bundle ID and count duplicates. Not a blocker for starting the plan; can be resolved as part of Step 2's on-device pass.
   - → **Resolved by 66-06-PLAN.md Task 1** (documented discretionary choice: bundle-identifier-only granularity for this MVP, with an inline comment referencing this Open Question).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Build | Yes | 26.6 (build 17F113) | — |
| Swift toolchain | Build | Yes | 6.3.3 | — |
| macOS (research/target machine) | On-device debugging | Yes | 27.0 (beta, build 26A5388g) | — |
| Ice.app (real binary, for live comparison) | D-07's core debugging premise | **No — dangling symlink only, actual bundle missing** | Cask receipt shows 0.11.12 installed 2026-04-13 | `brew reinstall --cask jordanbaird-ice` (Wave 0 blocker, not optional) |
| Accessibility TCC permission (for Islet's own bundle, during debugging) | All CGS enumeration/move calls | Unknown — not independently verifiable from this research session (TCC.db is FDA-protected) | — | Must be checked/set explicitly on-device as the debugging plan's first code change (Pattern 1, Step 2) |
| Git history access to deleted 66-01 files | Restoring the spike | Yes | Commit `adfbd70` + diagnostics `5f231f3`/`6136d7f`/`68bb5a2` all present and readable via `git show` | — |

**Missing dependencies with no fallback:** None that block planning — Ice.app's absence has a direct, one-command fallback (reinstall).

**Missing dependencies with fallback:** Ice.app (reinstall via brew). Accessibility TCC state (must be actively set/tested on-device, not assumed).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing project standard, `IsletTests/` target, app-hosted per `project.yml`'s `TEST_HOST` config) |
| Config file | `Islet.xcodeproj` scheme `Islet` — no separate `.xctestplan` |
| Quick run command | `xcodebuild build -scheme Islet -configuration Release -destination 'platform=macOS'` for build verification; manual Cmd-U or real-launch debug-menu action for the on-device CGS behavior itself (cannot be scripted headlessly — private WindowServer state) |
| Full suite command | Same build command (build-only; full `xcodebuild test` remains unusable headless per project memory — TCC-wait precedent) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MENUBAR-01 | Chevron separates visible/hidden sections | manual on-device UAT (visual, already passing per 66-04) | N/A — visual | ✅ Already built (`MenuBarOverflowController.swift`) |
| MENUBAR-02 | Cmd-drag another app's icon hides it | manual on-device UAT, blocked on the restored CGS move mechanism | End-of-debugging-plan checkpoint | ❌ Depends on restoring + fixing the CGS mechanism first |
| MENUBAR-03 | Click chevron reveals/hides, genuinely absent | manual on-device UAT (occlusion-vs-reclamation judgment, same as 66-01's original spike design) | End-of-debugging-plan checkpoint | ❌ Same dependency as MENUBAR-02 |
| MENUBAR-04 | Accessibility permission gate, visible explanation | manual on-device UAT (permission grant/deny flow) + the gate logic itself is a pure `Bool`-returning function, unit-testable in isolation | `xcodebuild build` for the gate function; visual check for the popover/Settings-row (already fully specified in UI-SPEC.md) | ❌ Wave 0 — gate logic doesn't exist yet (was print-only in the deleted spike) |

### Sampling Rate
- **Per task commit:** `xcodebuild build -scheme Islet -configuration Release -destination 'platform=macOS'`
- **Per wave merge:** Same build command
- **Phase gate:** On-device debugging checkpoint (Pattern 1's cheapest-first elimination) before any production Controller rewiring; then a full on-device UAT checkpoint (enumeration + move + persistence + permission gate together) before `/gsd:verify-work`, mirroring Plan 66-01's original blocking-spike-checkpoint structure — this phase is back to needing that structure, unlike the now-abandoned spacer-era research's lighter recommendation

### Wave 0 Gaps
- [ ] Restore `IsletTests/MenuBarOverflowManualSpike.swift` from `git show adfbd70` — currently absent
- [ ] Add the explicit `AXIsProcessTrusted()` gate (Pitfall 1) — does not exist in any currently-live or git-historical version of this code
- [ ] New `MenuBarOverflowAssignmentStore.swift` (D-03's persisted third-party assignment) — genuinely does not exist anywhere yet
- [ ] Remove or repurpose `IsletTests/MenuBarOverflowClampTests.swift` — tests a pure function (`clampedExpandedSpacerLength`) with no role under the CGS mechanism

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Single-user local macOS app, no auth surface |
| V3 Session Management | No | N/A |
| V4 Access Control | **Yes** | Accessibility (`AXIsProcessTrusted`) is a real, OS-enforced privileged-capability gate — this phase's core access-control surface. Confirmed required by Ice's own source (Permission.swift), not optional. Must be an actual gate (Pitfall 1), not a diagnostic log. |
| V5 Input Validation | No | No user-supplied or process-supplied text is parsed; window IDs/PIDs are opaque integers read from OS APIs, not attacker-controlled input in any meaningful sense for a local single-user app |
| V6 Cryptography | No | No sensitive data created or stored |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Silent/degraded operation under denied permission (feature appears to work but does nothing, or crashes) | Denial of Service (self-inflicted, UX-level) | Explicit gate + visible "chevron absent, Settings shows why" degraded state (UI-SPEC.md, Pitfall 1) — never let CGS calls run un-gated and silently fail |
| Synthetic CGEvent injection scoped too broadly | Elevation of Privilege (self-inflicted — accidentally affecting windows/processes beyond intent) | `moveMenuBarItem()` already scopes every synthetic event to one specific `windowID`/`pid` via `postToPid` + explicit field-stamping (verified in the restored shim) — do not widen this scope when restoring |

## Sources

### Primary (HIGH confidence)
- `github.com/jordanbaird/Ice` — `Ice/Bridging/Bridging.swift`, `Ice/Bridging/Shims/Private.swift`, `Ice/Permissions/Permission.swift`, `Ice/Permissions/PermissionsManager.swift`, `Ice/Utilities/StatusItemDefaults.swift`, `Ice/MenuBar/MenuBarItems/MenuBarItemInfo.swift`, `Ice/MenuBar/ControlItem/ControlItem.swift`, `Ice/MenuBar/MenuBarSection.swift`, `Ice/MenuBar/MenuBarItems/MenuBarItemManager.swift` (all fetched directly this session via `raw.githubusercontent.com/jordanbaird/Ice/main/...`, MIT license)
- This codebase — `Islet/Notch/MenuBarOverflowController.swift`, `Islet/Notch/CGSSpace.swift`, `Islet/Notch/FullscreenSpaceProbe.swift`, `Islet/Notch/OSDInterceptor.swift`, `Islet/Notch/CapsLockMonitor.swift`, `Islet/Notch/DropInterceptTap.swift`, `Islet/PermissionStatus.swift`, `Islet/SettingsView.swift`, `Islet/AppDelegate.swift`, `IsletTests/MenuBarOverflowClampTests.swift`, `project.yml` (all read directly, this session)
- This codebase's git history — `git show adfbd70:Islet/Notch/MenuBarOverflowBridging.swift`, `git show 68bb5a2` (diagnostic diff) — the deleted 66-01 spike's actual code, read directly
- Live filesystem checks (this session) — `/opt/homebrew/Caskroom/jordanbaird-ice/`, `brew list --cask`/`brew info --cask jordanbaird-ice`, `xcodebuild -version`, `swift --version`, `sw_vers`
- `.planning/phases/66-men-bar-overflow-ice-style-mvp/66-CONTEXT.md`, `66-01-SUMMARY.md`, `66-03-SUMMARY.md`, `66-04-SUMMARY.md`, `66-DISCUSSION-LOG.md`, `66-UI-SPEC.md` (all read directly, this session)

### Secondary (MEDIUM confidence)
- WebSearch for `jordanbaird/Ice` file locations (used only to locate exact file paths for direct fetching, not as a factual source itself)

### Tertiary (LOW confidence)
- None used as load-bearing claims in this document. Every concrete architectural/behavioral claim about Ice above was fetched and read directly this session, not recalled from training data.

## Metadata

**Confidence breakdown:**
- Standard stack / CGS signature comparison: HIGH — direct, byte-for-byte source comparison performed this session against Ice's live, current `main` branch source
- Permission-gating requirement (MENUBAR-04): HIGH — directly read from Ice's real `Permission.swift`/`PermissionsManager.swift`
- Persistence architecture (D-03): MEDIUM-HIGH — architecturally sound inference from Ice's real `StatusItemDefaults`/`MenuBarItemInfo`/`MenuBarSection` source, but the exact third-party re-apply code path was not traced to one single confirming function this session (see A4)
- Root-cause diagnosis itself (why 66-01 actually NO-GO'd): LOW-MEDIUM — this research narrows the hypothesis space with real evidence but does not have on-device confirmation; treat Pattern 1 as the plan's first task, not as already-resolved
- Environment findings (Ice.app missing, TCC unreadable, tool versions): HIGH — directly observed on this machine, this session

**Research date:** 2026-07-28
**Valid until:** ~14 days — this research is tightly coupled to the exact state of a beta macOS build, a specific (currently-missing) Ice installation, and git-history artifacts that could be further modified or garbage-collected; re-verify promptly if the debugging plan doesn't start within a couple of weeks, and immediately re-verify the Ice.app presence/version if any further Homebrew operations touch this cask.
