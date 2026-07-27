# Phase 66: Menübar-Overflow (Spacer-Technique MVP) - Research

**Researched:** 2026-07-27 (full replacement — supersedes the Ice-private-API research below after Plan 66-01's on-device NO-GO and the resulting mechanism pivot to the public-API spacer technique)
**Domain:** macOS menu-bar item overflow management via the public `NSStatusBar`/`NSStatusItem` API — a spacer status item whose `.length` is toggled to exploit AppKit's own menu-bar layout/overflow behavior
**Confidence:** HIGH (mechanism itself is a long-established public-API pattern used in production by multiple shipped apps for years — Hidden Bar, Bartender, Vanilla, Dozer — a fundamentally lower-risk domain than the superseded private-CGS mechanism)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Mechanism (revised 2026-07-27)
- **D-06 (NEW):** Build the hide/reveal mechanism using the spacer-`NSStatusItem` technique (Hidden Bar reference, public API only), NOT Ice's private-CGS-API/synthetic-CGEvent technique. This is the direct outcome of Plan 66-01's on-device NO-GO. `Islet/Notch/MenuBarOverflowBridging.swift` and `IsletTests/MenuBarOverflowManualSpike.swift` (the Ice-mechanism spike artifacts) are superseded — Claude's discretion whether to delete or repurpose them when the new plans are written; they must not be relied upon as-is.

#### Chevron placement & activation
- **D-01:** The chevron is the leftmost-positioned control item among Islet's menu-bar items — truly-hidden icons sit further left (off the visible strip, behind the widened spacer) and always-visible icons stay to the right, closer to the system clock. *(unchanged)*
- **D-02 (REVISED):** The feature activates automatically on app launch — there is no separate Settings on/off toggle for the mechanism itself, and (per the mechanism pivot) no permission gate of any kind to wait on either. This deliberately diverges from the v1.10 "new activities default OFF" convention, because Menübar-Overflow is not an `IslandResolver`/notch activity — it's a standalone menu-bar mechanism, same category as Quick Notes (Phase 64 D-13, menu-bar-only, zero resolver participation).

#### Persistence
- **D-03:** The hidden/visible icon assignment persists across app relaunch — Islet remembers which other apps' icons were hidden and restores that grouping the next time those icons are (re)created by their owning apps. **Open question for research/planning:** under the spacer technique, "hidden" is really just "positioned left of the spacer" — whether macOS's own system-level status-item-ordering persistence is sufficient on its own, or whether Islet still needs active re-apply logic on relaunch (the same class of risk as the original research's Pitfall 1, but the concrete mechanism differs now that no per-icon private-API repositioning is involved), is a technical question for the phase's research step, not decided here.

#### Reveal interaction (MENUBAR-03)
- **D-05:** Clicking the chevron reveals hidden icons **inline in the menu bar itself** (they slide/appear directly in the strip as the spacer narrows), not in a separate dropdown/popover. Clicking again re-hides them (spacer widens again). *(unchanged in spirit; mechanically it's now a width animation, not a per-icon move)*

#### Permission requirement — DROPPED (was MENUBAR-04 / old D-04)
- **D-04 (SUPERSEDED, kept for history):** ~~If Accessibility permission is denied, the chevron does not appear... Settings shows a "Permission required" state...~~ No longer applicable — the spacer technique requires no Accessibility permission. Do not implement any part of this.

### Claude's Discretion
- Exact persistence storage mechanism/format for D-03, informed by the research step's answer to the open question above.
- Chevron icon glyph/SF Symbol choice.
- Animation style for the reveal/hide width transition (D-05).
- Bounded max width for the spacer's "collapsed" state (Hidden Bar clamps to screen width to avoid pathological layout on newer macOS — mirror that discipline).
- Whether to delete or repurpose the now-superseded `MenuBarOverflowBridging.swift`/`MenuBarOverflowManualSpike.swift` spike artifacts (D-06).
- Whether Islet's **own** status item(s) (the main status item, and the debug-only status item) can also be dragged behind the chevron, or are exempt from hiding — default assumption remains **exempt** (Islet's own icon stays always visible) unless research finds a strong reason otherwise.
- All remaining technical mechanism details (exact spacer-width values, sleep/wake and Dock-relaunch behavior under the new technique) — research/planning work, not a discussion decision. Given the new mechanism is public-API-only and far less exotic than Ice's, a full on-device spike-gate may no longer be strictly necessary before production code — but that call belongs to research/planning, not this discussion.

### Deferred Ideas (OUT OF SCOPE)
- **Always-hidden/hotkey tier, menu-bar theming, hotkeys** — explicitly out of scope per this milestone's own MVP bound (PROJECT.md), reaffirmed here, not re-opened for discussion. (Both Ice and Hidden Bar have these extras; neither is in scope.)
- **Hiding Islet's own status item(s) behind the chevron** — not decided; left to Claude's discretion, default assumption is that Islet's own icon(s) stay exempt/always-visible (see Claude's Discretion above).
- **Retrying Ice's private-API mechanism / porting Ice's own Tahoe-compatibility fix** — considered and explicitly rejected during this discussion in favor of the spacer technique, given this hardware runs an even newer macOS beta (27.0) than Tahoe and the private-API approach was assessed as inherently fragile long-term.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MENUBAR-01 | A chevron icon in the menu bar separates a "visible" and a "hidden" section of menu-bar icons | Architecture Patterns (chevron + spacer `NSStatusItem` construction, reuses `AppDelegate.swift:107`/`:490` precedent) |
| MENUBAR-02 | The user can drag other apps' menu-bar icons across the chevron (standard macOS Cmd-drag) to assign them to the hidden section | Don't Hand-Roll (Cmd-drag is native, zero app code, unaffected by which technique owns the separator) |
| MENUBAR-03 | Clicking the chevron reveals/hides the hidden section's icons; hidden icons are genuinely absent from the visible menu-bar strip when hidden, not just repositioned off-screen while occupying visual space | Summary + Pitfall 3 (the spacer `.length` participates in AppKit's real menu-bar layout/overflow algorithm — this is the same system behavior that causes icons to silently disappear when there are "too many" of them; cross-verified against three independent production apps, not occlusion) |

*(MENUBAR-04 is dropped per CONTEXT.md D-04/D-06 — no permission-gating research needed; REQUIREMENTS.md itself still shows the original wording and is not yet updated for this phase.)*
</phase_requirements>

## Summary

The superseded research investigated Ice's private-CGS/synthetic-CGEvent mechanism, which Plan 66-01's on-device spike confirmed does not reliably work on this project's hardware/macOS build. This replacement research covers the new, pivoted mechanism: **Hidden Bar's spacer-`NSStatusItem` technique** (github.com/dwarvesf/hidden, MIT), which uses **only public `NSStatusBar`/`NSStatusItem` API**. The mechanism is structurally simple: two additional `NSStatusItem`s — a visible chevron (`NSStatusItem.variableLength`) and an invisible spacer (`NSStatusItem` with a `.length` toggled between ~20pt "collapsed" and ~2000pt "expanded," clamped to the current screen's width). Widening the spacer causes AppKit's own menu-bar layout engine to run out of room and stop displaying every item positioned to its left — this is the *same, well-documented, non-Islet-specific* macOS behavior that causes menu-bar icons to silently disappear when there are "too many" of them for the available width (confirmed independently for Bartender, corroborated by Jesse Squires' widely-cited notch-and-menu-bar article, and stated explicitly in Hidden Bar's own docs). This is genuine layout removal, not occlusion — a materially different (and much stronger) guarantee than the old Ice mechanism could offer, which could only *reposition* third-party items and never actually removed them from layout.

**Critically, the new mechanism needs no window/process introspection at all.** Unlike Ice's private CGS window-enumeration, the spacer technique is entirely oblivious to *which app* owns *which icon* — "hidden" is purely a geometric fact (an icon's X-position is left of the spacer's left edge) that AppKit itself computes and enforces. This eliminates the single largest risk class from the old research (private/undocumented API fragility) and the entire Accessibility-permission surface (MENUBAR-04, now dropped).

This reframes D-03's open persistence question with a concrete, evidence-backed answer (see Open Questions / Pitfall 1 below): **macOS's own system-level status-item position persistence is the primary and largely sufficient mechanism** — it is documented, real AppKit behavior (`NSStatusItem.autosaveName`), not a guess. Hidden Bar's own manual states plainly that "macOS remembers that placement per app" once a user has Cmd-dragged an icon across the separator, and that this persists across that *other* app's relaunches — because the persisted state lives in the *system's* per-item-identity position table, not in Hidden Bar's own storage. The one documented edge case is a brand-new or updated third-party status item with no prior remembered position: macOS's own default insertion behavior places new items at the *outer* edge of the menu-extras cluster (farthest from the clock) — which, given D-01's leftmost-chevron placement, biases toward landing in (or near) the *hidden* zone rather than randomly in the visible one. This means Islet's own required persistence work is much smaller in scope than the old mechanism needed: mainly, giving **Islet's own** chevron and spacer items a stable `autosaveName` (so the boundary reference point itself doesn't drift across launches) plus persisting Islet's own UI state (is the hidden section currently expanded or collapsed) — not a bespoke "list of hidden bundle IDs + active re-apply on relaunch" store, which was the old mechanism's Pitfall 1 conclusion but does not transfer to this one.

**Primary recommendation:** Build this as a direct production implementation, not a spike-gated exploratory plan. The mechanism is public API, has multiple years of production precedent across at least three shipped apps, and needs no permission or private-symbol validation. Skip a dedicated `checkpoint:human-verify` spike plan (unlike Plan 66-01); fold on-device visual confirmation of "genuine reclamation vs. occlusion" into a lightweight UAT checkpoint at the end of the first real implementation task instead, mirroring how most of this project's non-exotic features are verified (Wave-end on-device check, not a whole preceding spike wave).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Chevron + spacer `NSStatusItem` creation, click handling, width toggling | App process (new isolated manager type, constructed from `AppDelegate`) | Settings UI (SwiftUI) — none needed per D-02, no toggle/status card | Follows `AppDelegate.swift:107`/`:490` `statusItem`/`debugStatusItem` construction precedent; D-02 removes any Settings-tier involvement entirely |
| Other apps' icon hide/reveal ordering | macOS Window Server / AppKit menu-bar layout engine (out-of-process, public behavior) | New isolated manager type (owns only the spacer's `.length`, never touches other apps' items directly) | This phase's app code never references another app's `NSStatusItem` at all — the entire "move an icon" concept from the old mechanism does not exist here; AppKit's own layout algorithm does 100% of the work once the spacer's length changes |
| Cmd-drag repositioning gesture | macOS system (native, zero app code) | — | Cmd-dragging any `NSStatusItem`, including third-party ones, across another item is native macOS behavior, unaffected by which technique owns the separator (confirmed in both Ice's and Hidden Bar's source, per CONTEXT.md) |
| Hidden/visible icon-position persistence (D-03) | macOS system-level `NSStatusItem` position table (per-app, `autosaveName`-anchored) | New isolated manager type — persists Islet's own reveal/hide UI state (bool) and gives Islet's own items stable `autosaveName`s | See Summary/Pitfall 1 — the heavy lifting is OS-native; Islet's own code only needs to keep its own boundary-defining items stable, not track other apps' bundle IDs |
| Screen-width-bounded "expanded" spacer length | New isolated manager type, reacting to `NSApplication.didChangeScreenParametersNotification` | — | Must be recomputed on every screen-configuration change (external display connect/disconnect, resolution change), not captured once at launch — codebase already has this exact notification pattern at `NotchWindowController.swift:604` |

## Standard Stack

### Core

No new external package dependency. The entire mechanism is built from public `AppKit` APIs already used elsewhere in this codebase.

| Approach | Purpose | Why Standard (for this exact problem) |
|----------|---------|----------------------------------------|
| `NSStatusBar.system.statusItem(withLength:)` (chevron, `NSStatusItem.variableLength`) | Visible chevron control | `[VERIFIED: codebase]` — identical call already used at `Islet/AppDelegate.swift:107` and `:490` |
| `NSStatusBar.system.statusItem(withLength:)` (spacer, numeric length toggled between ~20 and a screen-width-bounded ~2000) | The actual hide/reveal mechanism | `[CITED: github.com/dwarvesf/hidden, StatusBarController.swift — fetched directly]` — `btnSeparate = NSStatusBar.system.statusItem(withLength: 1)`, then `btnHiddenLength`/`btnHiddenCollapseLength` toggled on click |
| `NSStatusItem.autosaveName` | Give Islet's own chevron/spacer a stable position reference across relaunches (answers D-03's open question) | `[CITED: github.com/dwarvesf/hidden, StatusBarController.swift]` — Hidden Bar sets `btnExpandCollapse.autosaveName = "hiddenbar_expandcollapse"` / `btnSeparate.autosaveName = "hiddenbar_separate"`; this is a documented public `NSStatusItem` property, not a private one |
| `NSApplication.didChangeScreenParametersNotification` | Recompute the spacer's bounded "expanded" length on display changes | `[VERIFIED: codebase]` — identical pattern already used at `Islet/Notch/NotchWindowController.swift:604` for an unrelated purpose (ISL-06) |
| `UserDefaults` | Persist Islet's own small UI state (expanded/collapsed) — NOT a bundle-ID hidden-list (see Summary) | `[VERIFIED: codebase]` — standard project pattern (`ActivitySettings`) |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `NSWorkspace.didLaunchApplicationNotification`/`didTerminateApplicationNotification` | AppKit (built-in) | Optional: detect a Dock-relaunch of another app, purely for debug logging / future diagnostics — NOT required for the core hide/show mechanism to function (see Pitfall 1) | `[VERIFIED: codebase]` — identical pattern already used at `Islet/Notch/MeetingMonitor.swift:119-120` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| macOS's own `autosaveName`-based position persistence for D-03 | A bespoke `UserDefaults`-backed bundle-ID → hidden/visible store with active re-apply logic on every app relaunch (the old research's Pitfall-1-driven design) | `[CITED, MEDIUM confidence]` — this was the correct answer for the *old* mechanism (which had zero persisted state of any kind), but is unnecessary complexity here: it would duplicate a system-level guarantee that already exists for this specific mechanism, and risks *fighting* macOS's own remembered order rather than complementing it. Revisit only if on-device UAT finds the OS-level persistence measurably unreliable for this project's actual icon set. |
| A fixed collapsed-spacer max width (e.g. a hardcoded `2000`) | Screen-width-bounded value, recomputed on screen-parameter change | `[CITED: github.com/dwarvesf/hidden]` — Hidden Bar clamps between roughly 500–4000pt based on the *current* screen, specifically to avoid pathological layout on newer macOS; a hardcoded value would misbehave on this project's notch MacBook's narrower usable menu-bar width (`CLAUDE.md` confirms notch MacBooks are the sole target platform) |

**Installation:** No package manager changes required — no SPM package additions. New Swift source files only.

**Version verification:** N/A — no versioned package is being added; all APIs used (`NSStatusBar`, `NSStatusItem`, `NSApplication.didChangeScreenParametersNotification`) are stable public AppKit surface, present since long before this project's macOS 14.0+ deployment target.

## Package Legitimacy Audit

Not applicable — this phase adds no new external package dependency. The entire mechanism is public-API AppKit code; no packages to verify via slopcheck or registry lookups.

**Packages removed due to slopcheck verdict:** none (no packages proposed).
**Packages flagged as suspicious:** none.

## Architecture Patterns

### System Architecture Diagram

```
┌───────────────────────────────────────────────────────────────────────┐
│  macOS Menu Bar (AppKit's own layout engine, out-of-process)          │
│                                                                          │
│  [3rd-party icon A]  [3rd-party icon B]  ...  [Islet chevron][spacer] │
│  ◄── pushed out of layout when spacer.length grows past available ──► │
│      width; AppKit itself removes them from the visible strip          │
│      (genuine layout removal — same mechanism that silently drops      │
│      icons when there are "too many" for the screen)                   │
└───────────────────────────▲─────────────────────────────────────────┘
                             │ NSStatusItem.length (public property)
                             │ set on Islet's OWN spacer item only —
                             │ zero reads/writes of any other app's item
┌────────────────────────────┴────────────────────────────────────────┐
│  Islet app process                                                    │
│                                                                        │
│  AppDelegate ──creates──► ChevronStatusItem (variableLength,          │
│      │                     leftmost per D-01, autosaveName set)       │
│      │                     ──click──► toggle expanded/collapsed (D-05)│
│      │                                                                 │
│      ├──creates──► SpacerStatusItem (invisible, autosaveName set)     │
│      │              ├─ collapsed: length ≈ 20pt (hidden section open) │
│      │              └─ expanded: length ≈ 2000pt, clamped to current  │
│      │                 screen width (hidden section closed)           │
│      │                                                                 │
│      ├──observes──► NSApplication.didChangeScreenParametersNotif.     │
│      │               (recompute the clamp bound on display change,    │
│      │               reuses NotchWindowController.swift:604 pattern)  │
│      │                                                                 │
│      ├──persists (UserDefaults)──► own expanded/collapsed UI state    │
│      │               (NOT a per-bundle-ID hidden list — see Summary)  │
│      │                                                                 │
│      └── NO code anywhere reads/writes another app's NSStatusItem,    │
│          NO window enumeration, NO Accessibility permission gate      │
└────────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure

```
Islet/Notch/  (or a new Islet/MenuBar/ group)
├── MenuBarOverflowController.swift   # owns chevron + spacer NSStatusItems, toggle logic, screen-width clamp
└── (construction lives in AppDelegate.swift, alongside statusItem/debugStatusItem)

# Superseded, D-06 discretion — delete or repurpose, do not build on:
Islet/Notch/MenuBarOverflowBridging.swift        # old private-CGS shim
IsletTests/MenuBarOverflowManualSpike.swift      # old private-API spike test
```

### Pattern 1: Two-status-item spacer toggle (the core mechanism)

**What:** A dedicated, invisible `NSStatusItem` whose only job is to occupy width. Toggling its `.length` between a small "collapsed" value and a large "expanded" value (clamped to the current screen's usable width) is the entire hide/reveal mechanism — no other app code participates.

**When to use:** Exactly MENUBAR-01/MENUBAR-03's mechanism.

**Example (reconstructed from Hidden Bar's real source, fetched directly — verify exact property names/values against the live file before copying literally into production code):**
```swift
// Source: github.com/dwarvesf/hidden, hidden/Features/StatusBar/StatusBarController.swift
private let btnExpandCollapse = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
private let btnSeparate = NSStatusBar.system.statusItem(withLength: 1)

private var btnHiddenLength: CGFloat = 20
private var btnHiddenCollapseLength: CGFloat = 2000   // clamped to current screen width, see Pitfall 4

func expandCollapseIfNeeded() {
    let isCollapsed = btnSeparate.button?.frame.width == btnHiddenCollapseLength
    btnSeparate.length = isCollapsed ? btnHiddenLength : btnHiddenCollapseLength
}
```

### Pattern 2: `autosaveName` for Islet's own boundary-defining items (directly answers D-03's open question)

**What:** Set a stable, hardcoded `autosaveName` string on both the chevron and spacer `NSStatusItem`s so macOS's own system-level position table anchors them consistently across relaunches. This is what makes the *reference point* for "hidden = left of spacer" stable — everything else (other apps' items) is then persisted by the OS relative to that stable anchor.

**When to use:** Required for D-03. Set once, at construction, alongside `AppDelegate.swift:107`'s existing `statusItem` construction.

**Example:**
```swift
// Source: github.com/dwarvesf/hidden, StatusBarController.swift (public NSStatusItem API, not private)
btnExpandCollapse.autosaveName = "hiddenbar_expandcollapse"
btnSeparate.autosaveName = "hiddenbar_separate"
```

### Pattern 3: Screen-parameter-driven re-clamp (reuses existing codebase pattern)

**What:** Recompute the spacer's "expanded" length bound whenever the screen configuration changes (external display connect/disconnect, resolution change, notch-MacBook lid open/close) — never capture a single value once at launch.

**When to use:** Required for correctness on the notch MacBook target hardware, whose built-in display already has a physically narrower usable menu-bar width than a non-notch Mac.

**Example:**
```swift
// Source: Islet/Notch/NotchWindowController.swift:601-610 (this codebase, existing pattern for
// an unrelated purpose — ISL-06/D-05 — directly reusable shape for this phase)
observer = NotificationCenter.default.addObserver(
    forName: NSApplication.didChangeScreenParametersNotification,
    object: nil, queue: .main
) { [weak self] _ in
    DispatchQueue.main.async { self?.recomputeSpacerExpandedLength() }
}
```

### Pattern 4: Position-validity self-heal (defensive, optional but recommended)

**What:** Hidden Bar checks, on each interaction, whether its own control items are still in a sane relative order (`isBtnSeparateValidPosition`/`isBtnAlwaysHiddenValidPosition`) and self-corrects if the user has Cmd-dragged the chevron/spacer itself out of its expected place — since nothing in the public API can *prevent* the user from doing so (see Open Question 2 below re: "exempt" own-item semantics).

**When to use:** Optional hardening for Claude's Discretion item ("Islet's own icon(s) exempt from hiding") — since true enforcement isn't possible via public API, a self-heal check is the closest achievable approximation.

### Anti-Patterns to Avoid

- **Reading/writing another app's `NSStatusItem` object:** Not possible cross-process, and not needed — this mechanism never references one. If a future task is tempted to add window/process introspection "to be sure," that's a sign of porting the old mechanism's mental model where it doesn't apply.
- **Recreating the spacer/chevron `NSStatusItem` on every toggle:** Only `.length` should change; recreating the item loses its `autosaveName`-anchored position and is unnecessary churn (mirrors Hidden Bar's own single-instance-per-launch construction).
- **Hardcoding a fixed max width instead of clamping to the current screen:** Will misbehave on this project's notch hardware and on any external-display setup (Pitfall 4).
- **Building a bundle-ID-keyed hidden-list store with active re-apply logic as the primary D-03 mechanism:** Unnecessary for this mechanism (see Alternatives Considered) — the OS already does this for the common case; over-building here duplicates a system guarantee.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cmd-drag repositioning of a menu-bar icon | Custom `NSDraggingSession`/drop-target code | Nothing — free, native macOS behavior for any `NSStatusItem`, including third-party ones | Confirmed in both Ice's and Hidden Bar's source (per CONTEXT.md); unaffected by which technique owns the separator |
| Hidden-icon position persistence across relaunch | A bespoke bundle-ID-keyed `UserDefaults` store + active re-apply-on-relaunch subscriber | `NSStatusItem.autosaveName` on Islet's own items, relying on macOS's own per-app position table for everyone else's items | See Summary/Pitfall 1 — this is the single biggest scope reduction the mechanism pivot enables; do not port the old mechanism's Pitfall-1-driven design forward |
| Detecting "is the vacated space genuinely reclaimed" | A custom `CGWindowListCopyWindowInfo` visual-diff check at runtime | Trust the mechanism (public `NSStatusItem.length` participating in AppKit's real layout algorithm) — confirm once, visually, during UAT, not via runtime introspection code shipped in the app | The old mechanism needed a runtime check because it could not know its own effect (private repositioning with unknown layout consequences); this mechanism's effect on layout is deterministic AppKit behavior, not something the app needs to verify at runtime |

**Key insight:** The mechanism pivot doesn't just change *how* hide/reveal works — it eliminates two entire problem classes the old research had to solve (private-API window introspection, and active persistence re-application). The remaining genuinely novel code is small: the chevron+spacer construction, the width-toggle/animation, and the screen-width clamp. Plans should be scoped accordingly — this is a meaningfully smaller phase than the superseded research anticipated.

## Common Pitfalls

### Pitfall 1: D-03's open question, resolved — macOS's own position persistence is sufficient for the common case, but Islet's OWN items must be pinned via `autosaveName`

**What goes wrong:** Assuming either extreme — either "macOS remembers everything, build nothing" or "nothing persists automatically, build a full bundle-ID store" — is wrong in different ways.

**Why it happens:** `[CITED: github.com/dwarvesf/hidden, docs/MANUAL.md — fetched directly]` — Hidden Bar's own manual states plainly that once a user Cmd-drags an icon across the separator, "macOS remembers that placement per app," and that this is *system* behavior ("this is macOS positioning behavior, not Hidden Bar moving your icon"), not something Hidden Bar's own code tracks or re-applies. The one documented gap: brand-new or updated third-party items with no prior remembered position get inserted at the *outer* edge of the menu-extras cluster by macOS's own default rule — which, given D-01's leftmost-chevron placement, tends to land at or near the hidden zone rather than randomly in the visible one, but this is not a hard guarantee `[ASSUMED — inferred from the "new items insert at the far/outer edge" description, not independently confirmed against Apple's own documentation]`. Separately, `[CITED: multiple developer-forum threads found via WebSearch]` confirms `NSStatusItem.autosaveName` is the actual public mechanism macOS uses for this per-app remembered-position behavior, and that it is opt-in per item — an item with no `autosaveName` set has no persisted position guarantee at all. This matters directly for Islet's **own** chevron and spacer: if they don't set a stable `autosaveName`, the *reference point* itself could drift across relaunches, which would make the whole hidden/visible boundary unstable even if every other app's item persists correctly.

**How to avoid:** Set `NSStatusItem.autosaveName` on both the chevron and spacer with a hardcoded, stable string (mirrors Hidden Bar's `"hiddenbar_expandcollapse"`/`"hiddenbar_separate"`) at construction time, alongside `AppDelegate.swift:107`'s existing pattern. Do NOT build a bundle-ID-keyed hidden/visible store with active re-apply logic as the primary persistence mechanism — that solves a problem this mechanism mostly doesn't have. Persist only Islet's own small UI state (is the hidden section currently expanded or collapsed) via plain `UserDefaults`.

**Warning signs:** The chevron or spacer appearing at a different relative position after a fresh app launch than where it was left — this would indicate the `autosaveName` wiring is missing or broken, and should be treated as a correctness bug, not a cosmetic one.

### Pitfall 2: Cmd-dragging Islet's own chevron/spacer is not preventable via public API

**What goes wrong:** Assuming "Islet's own icon(s) stay exempt from hiding" (the default discretion assumption) can be enforced programmatically.

**Why it happens:** Cmd-drag repositioning is a system-level gesture that applies to *any* `NSStatusItem` a user can see, including Islet's own — there is no public API to disable or intercept it for a specific item. `[CITED: github.com/dwarvesf/hidden, docs/MANUAL.md]` — Hidden Bar's own manual acknowledges this exact limitation for its own control items ("if the arrow or separator was Command-dragged off the bar... they come back on next launch" — a self-heal, not a prevention).

**How to avoid:** Treat "exempt from hiding" as a *default positioning* guarantee (constructed to the right of the spacer, in the visible zone), not an enforced constraint. Optionally add Pattern 4's self-heal check to detect and correct if Islet's own items end up out of their expected relative order. Document this limitation explicitly rather than promising the user something the public API can't deliver.

**Warning signs:** A support report that "Islet's icon disappeared" — likely the user accidentally Cmd-dragged it behind their own spacer, not a bug in the hide/reveal mechanism itself.

### Pitfall 3: Genuine reclamation (not occlusion) is the mechanism's actual behavior — but confirm on-device once, don't assume unconditionally

**What goes wrong:** Carrying forward the old research's Pitfall 2 anxiety ("is this occlusion or reclamation?") unnecessarily, OR conversely assuming zero on-device verification is needed at all.

**Why it happens:** `[CITED: multiple independent sources]` — general reporting on `NSStatusItem` overflow behavior confirms "when there are too many app icons on the menu bar, macOS automatically hides some of them" as real, system-level layout behavior (not an app-specific trick), and this is corroborated independently by Bartender's documented technique and by developer commentary on the notch reducing available menu-bar width. This is a fundamentally different (and stronger) guarantee than Ice's private repositioning ever offered. However, this research is based on cross-referenced secondary sources plus one direct fetch of Hidden Bar's real file, not a live on-device test on this project's actual hardware/macOS 27 beta.

**How to avoid:** A single lightweight on-device visual check (do hidden icons genuinely vanish and does the visible strip's width change, versus merely getting covered by the frontmost app's menu) is still worth doing once, as an end-of-task UAT checkpoint — not as a full blocking spike wave like Plan 66-01 was. Given the strength of the corroborating evidence, this should be a fast confirmation, not an open-ended investigation.

**Warning signs:** If, contrary to all corroborating evidence, hidden icons remain visually present after collapse on this specific hardware/macOS build — this would be a genuinely novel finding worth its own follow-up investigation, not something to silently work around.

### Pitfall 4: The "expanded" spacer length must be clamped to the CURRENT screen, recomputed on change — not a fixed constant

**What goes wrong:** Hardcoding `btnHiddenCollapseLength = 2000` (or any fixed value) without accounting for the actual current screen width, or capturing the bound once at launch.

**Why it happens:** `[CITED: github.com/dwarvesf/hidden, StatusBarController.swift]` — Hidden Bar itself bounds this value dynamically (roughly 500–4000pt, clamped to `NSScreen.main?.visibleFrame.width`) specifically to avoid pathological layout on newer macOS. This project's sole target platform is notch MacBooks (per `CLAUDE.md`'s own platform constraint), whose built-in display has a physically narrower usable menu-bar width than a non-notch Mac to begin with — an even stronger reason to clamp dynamically rather than trust a fixed constant. External-display connect/disconnect also changes the effective screen width mid-session.

**How to avoid:** Recompute the bound inside the `NSApplication.didChangeScreenParametersNotification` handler (Pattern 3), using the screen the menu bar currently renders on, not a value captured once at app launch.

**Warning signs:** The expanded spacer overshooting or undershooting on an external monitor, or behaving differently before/after a display is connected without an app relaunch.

### Pitfall 5: Sleep/wake is a non-issue for this mechanism — do not port forward the old mechanism's sleep/wake concern

**What goes wrong:** Assuming sleep/wake needs dedicated handling because the superseded research's ROADMAP success-criteria wording (SC#1) explicitly called it out as a spike checklist item for the *old* mechanism.

**Why it happens:** The old mechanism's sleep/wake risk was tied to synthetic `CGEvent` injection and Accessibility-permission state, both of which no longer exist in this design. The spacer technique touches nothing but Islet's own in-process `NSStatusItem.length` — a value that simply persists in memory across sleep like any other app state, with no OS-level teardown on sleep.

**How to avoid:** Do not add sleep/wake-specific handling (`NSWorkspace.screensDidSleepNotification`/`didWakeNotification`) unless a genuine, observed on-device issue surfaces — there is no known mechanism-specific reason to expect one. This is a scope reduction versus the old research's SC#1 checklist, not an oversight.

**Warning signs:** None expected; only add handling reactively if UAT surfaces an actual problem.

## Code Examples

### Two-status-item construction and toggle (reconstructed from Hidden Bar's real source — verify exact property/method names against the live file before production use)

```swift
// Source: github.com/dwarvesf/hidden, hidden/Features/StatusBar/StatusBarController.swift (fetched directly)
private let btnExpandCollapse = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
private let btnSeparate = NSStatusBar.system.statusItem(withLength: 1)

private var btnHiddenLength: CGFloat = 20
private var btnHiddenCollapseLength: CGFloat = 2000  // clamped dynamically, see Pitfall 4

@objc func btnExpandCollapsePressed(sender: NSStatusBarButton) {
    if let event = NSApp.currentEvent, event.type == .leftMouseUp {
        expandCollapseIfNeeded()
    }
}
```

### Existing codebase pattern for screen-parameter-driven recompute (directly reusable shape)

```swift
// Source: Islet/Notch/NotchWindowController.swift:601-610 (this codebase)
observer = NotificationCenter.default.addObserver(
    forName: NSApplication.didChangeScreenParametersNotification,
    object: nil, queue: .main
) { [weak self] _ in
    DispatchQueue.main.async { self?.updateVisibility() }
}
```

### Existing codebase pattern for the chevron/spacer's own `NSStatusItem` construction site

```swift
// Source: Islet/AppDelegate.swift:107 (this codebase)
statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
```
The new chevron and spacer items follow this same construction call, added alongside `statusItem`/`debugStatusItem` (`AppDelegate.swift:490`), confirming no structural conflict with running multiple simultaneous `NSStatusItem` instances — already proven in this exact app in Debug builds.

## State of the Art

| Old Approach (superseded, this phase) | Current Approach | When Changed | Impact |
|--------------------------------------|-------------------|---------------|--------|
| Ice's private `CGS*`-symbol window enumeration + synthetic-`CGEvent` drag repositioning, gated behind Accessibility permission | Public `NSStatusItem.length` spacer toggle, no permission, no window introspection | This phase's own pivot (2026-07-27), following Plan 66-01's on-device NO-GO | Eliminates the private-API fragility risk (old Pitfall 3), the occlusion-vs-reclamation uncertainty (old Pitfall 2, now resolved in this mechanism's favor), and the entire permission-gating surface (old MENUBAR-04, now dropped) |

**Deprecated/outdated:** The old research's Ice-mechanism findings remain historically accurate for what they described (Ice's real source, as read on 2026-07-27) but no longer describe this phase's chosen mechanism — do not port forward any conclusion from that document that assumes private-CGS APIs, Accessibility gating, or per-icon window repositioning.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | New/updated third-party status items with no prior remembered position get inserted at the outer/left edge of the menu-extras cluster by macOS's own default rule, biasing toward the hidden zone rather than landing randomly in the visible one | Pitfall 1 | If wrong, a newly-installed or updated app's icon could unexpectedly appear in the *visible* zone on first launch even though the user never explicitly un-hid it — a minor UX surprise, not a correctness failure of the core mechanism, and easily caught during on-device UAT |
| A2 | The mandated on-device visual confirmation of "genuine reclamation vs. occlusion" (Pitfall 3) will confirm the corroborating secondary-source evidence on this project's specific macOS 27 beta hardware | Summary, Pitfall 3 | If wrong (i.e., this specific macOS beta build behaves differently from years of prior-version precedent), MENUBAR-03 as worded would need re-scoping — low probability given the mechanism is fundamental AppKit layout behavior, not a version-fragile private API, but not zero given the project runs a beta OS |
| A3 | A dedicated blocking spike-gate plan (mirroring Plan 66-01's structure) is not necessary for this mechanism, and a lighter end-of-task UAT checkpoint suffices | Summary, Pitfall 3 | If wrong, the planner would need to add a blocking checkpoint earlier than currently recommended — low-severity, easily corrected by the planner if it disagrees with this recommendation |

**If this table is empty:** N/A — see entries above. None of A1-A3 need to block planning; A2's resolution is exactly what an end-of-task UAT checkpoint (Pitfall 3's recommendation) is designed to catch early and cheaply.

## Open Questions

1. **Does macOS's own `autosaveName`-based position persistence hold reliably for the actual set of third-party menu-bar apps this user runs, or will some subset of them lack a stable identity and require manual re-hiding after every relaunch?**
   - What we know: The mechanism is real, documented, and Hidden Bar's own manual describes it as generally reliable in production.
   - What's unclear: Whether *every* app the user actually runs sets up its own status item in a way that participates cleanly in this system behavior — some apps are known (from general community reports) to behave inconsistently here.
   - Recommendation: Not a blocker for planning or implementation — this is inherent, pre-existing macOS behavior outside Islet's control either way, and the UX cost of an occasional manual re-hide is low. Worth a one-line mention in user-facing copy/documentation, not engineering work.

2. **Should Islet's own status items be literally undraggable, or is the "exempt by default positioning + optional self-heal" answer (Pitfall 2) sufficient for this MVP?**
   - What we know: True prevention isn't possible via public API (Pitfall 2).
   - What's unclear: Whether the self-heal pattern (Pattern 4) is worth the extra code for an MVP, or whether "exempt by default construction order" alone is good enough until a user actually reports the edge case.
   - Recommendation: Claude's Discretion per CONTEXT.md — lean toward skipping the self-heal check for MVP scope (YAGNI) unless the planner judges it trivially cheap to add alongside the core toggle logic; document the limitation either way.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Build | ✓ | 26.6 (research machine) | — |
| Swift toolchain | Build | ✓ | 6.3.3 | — |
| macOS (research machine) | N/A — not the deployment target | ✓ | 27.0 (beta) | Deployment target remains 14.0+/15.0+ per project; on-device UAT must run on the user's actual target hardware |
| Accessibility TCC permission | **None** — this mechanism requires no permission at all | N/A | — | N/A |

**Missing dependencies with no fallback:** None identified — this is a code-only phase against an already-configured Xcode project, using only stable public AppKit API.

**Missing dependencies with fallback:** None.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing project standard, `IsletTests/` target) |
| Config file | `Islet.xcodeproj` scheme `Islet` — no separate `.xctestplan` |
| Quick run command | `xcodebuild build -scheme Islet -configuration Release -destination 'platform=macOS'` for the pure-logic pieces (width clamp math, position-validity check if built); manual Cmd-U or on-device run for the visual chevron/spacer behavior itself |
| Full suite command | `xcodebuild build -scheme Islet -configuration Release -destination 'platform=macOS'` (build-only; full `xcodebuild test` remains unusable headless per project memory — TCC-wait precedent, `.planning/PROJECT.md`) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MENUBAR-01 | Chevron appears, separates visible/hidden sections | manual on-device UAT (visual) | End-of-task checkpoint visual check | ❌ Wave 0 — new file(s) |
| MENUBAR-02 | Cmd-drag another app's icon across the chevron moves it to hidden | manual on-device UAT (native OS gesture, cannot be scripted via XCTest) | End-of-task checkpoint drag test | ❌ Wave 0 |
| MENUBAR-03 | Click chevron reveals/hides; hidden icons genuinely absent (Pitfall 3) | manual on-device UAT (visual space-reclamation confirmation) + unit test for the pure width-clamp math | `xcodebuild build` for the pure function; visual check for the rest | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `xcodebuild build -scheme Islet -configuration Release -destination 'platform=macOS'`
- **Per wave merge:** Same full build command
- **Phase gate:** One on-device UAT checkpoint (chevron appears, drag works, reveal/hide genuinely changes visible strip width) before `/gsd:verify-work` — lighter-weight than the superseded mechanism's Plan-66-01-style blocking spike wave (Pitfall 3/Summary)

### Wave 0 Gaps
- [ ] Unit test for the spacer's expanded-length clamp math (`min(max(candidate, lowerBound), currentScreenWidth)`-shaped pure function) if the implementation extracts it as a testable pure function, mirroring this project's existing pure-function testing style
- [ ] No existing test file covers any part of this phase — the superseded `IsletTests/MenuBarOverflowManualSpike.swift` tested the OLD mechanism and should not be extended for this one (D-06 discretion: delete or fully rewrite, don't patch)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Single-user local macOS app, no auth surface |
| V3 Session Management | No | N/A |
| V4 Access Control | No | Unlike the superseded mechanism, this phase requires **zero** permission gating of any kind — D-04/MENUBAR-04 are fully dropped; there is no privileged capability being requested |
| V5 Input Validation | No | No user-supplied or process-supplied text is read or parsed by this mechanism at all (a meaningful simplification versus the old mechanism, which read bundle identifiers from OS APIs) |
| V6 Cryptography | No | No sensitive data of any kind is created or stored by this feature |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| None identified specific to this mechanism | — | The spacer technique has no elevated-privilege capability, no cross-process data access, and no persisted sensitive data — a materially smaller security surface than the superseded mechanism, which required scoping synthetic-event generation narrowly (no longer applicable here) |

## Sources

### Primary (HIGH confidence)
- This codebase — `Islet/AppDelegate.swift:107`, `:490` (`statusItem`/`debugStatusItem` construction, direct read)
- This codebase — `Islet/Notch/NotchWindowController.swift:598-615` (`didChangeScreenParametersNotification` pattern, direct read)
- This codebase — `Islet/Notch/MeetingMonitor.swift:110-135` (`NSWorkspace` launch/terminate notification pattern, direct read)
- This codebase — `.planning/phases/66-men-bar-overflow-ice-style-mvp/66-CONTEXT.md`, `66-01-SUMMARY.md` (direct read)
- General web reporting on `NSStatusItem` menu-bar overflow behavior — multiple independent sources cross-referenced (WebSearch), confirming the core layout-removal mechanism is real, non-app-specific AppKit behavior

### Secondary (MEDIUM confidence)
- github.com/dwarvesf/hidden — `hidden/Features/StatusBar/StatusBarController.swift` (fetched directly via WebFetch, code shape confirmed but not read as raw bytes in this session — verify exact property/method names against the live file before literal production use)
- github.com/dwarvesf/hidden — `docs/MANUAL.md`, GitHub Discussion #162 (fetched via WebFetch, position-persistence and always-hidden behavior claims)
- Developer-forum threads on `NSStatusItem.autosaveName` and macOS status-item position persistence (WebSearch, cross-referenced across multiple threads)

### Tertiary (LOW confidence)
- None used as load-bearing claims in this document.

## Metadata

**Confidence breakdown:**
- Standard stack (public API mechanism identification): HIGH — established production pattern across multiple shipped apps (Hidden Bar, Bartender, Vanilla), materially lower risk than the superseded private-API mechanism
- Architecture (D-03 persistence resolution): MEDIUM-HIGH — grounded in Hidden Bar's own documentation plus general `autosaveName` corroboration, but not independently confirmed via a live on-device test in this session
- Pitfalls (screen-width clamp, sleep/wake non-issue, own-item drag limitation): HIGH for the codebase-precedented parts, MEDIUM for the macOS-version-specific reclamation claim (Pitfall 3) pending the phase's own lightweight on-device confirmation

**Research date:** 2026-07-27
**Valid until:** ~30 days — this mechanism relies on stable, long-established public AppKit API rather than undocumented private symbols, so it is materially less time-sensitive than the superseded research; re-verify only if a macOS point release changes menu-bar-overflow layout behavior
