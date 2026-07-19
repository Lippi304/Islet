# Phase 44: Tray & Quick Action Width Alignment - Pattern Map

**Mapped:** 2026-07-19
**Files analyzed:** 3 (all modified, no new files)
**Analogs found:** 3 / 3 (all exact — this phase reuses an established in-file precedent, "the geometry three-site rule", already proven by `trayFrame`/`weatherExpandedFrame`)

## File Classification

| Modified File | Role | Data Flow | Closest Analog | Match Quality |
|----------------|------|-----------|-----------------|----------------|
| `Islet/Notch/NotchWindowController.swift` (`quickActionPickerFrame`, ~line 1023-1025) | controller (AppKit panel geometry) | request-response (pure geometry computation) | same file, `trayFrame` (~line 1003-1005) / `weatherExpandedFrame` (~line 1016-1018) | exact — identical role, same function, same union-of-frames pattern |
| `Islet/Notch/NotchWindowController.swift` (`contentSize` branch, ~line 1392) | controller (AppKit hot-zone geometry) | request-response | same file, `.trayExpanded` branch (~line 1371-1373) | exact — identical if/else-if ladder, same function |
| `Islet/Notch/NotchPillView.swift` (`quickActionPickerView()`, ~line 1471-1477) | component (SwiftUI view) | request-response (declarative render) | same file, `trayFullView` (~line 1399-1402) | exact — both call `blobShape(...)` directly with `width:`/`height:` overrides |
| `Islet/Notch/NotchPillView.swift` (`quickActionPickerContentHeight` constant, ~line 727) | config (static layout constant) | n/a | same file, `trayContentHeight`/`calendarWidth` constants (~line 663-672) | exact — same declaration style + doc-comment convention |
| `Islet/Notch/DragDropSupport.swift` (`computeQuickActionButtonFrames`, ~line 55) | utility (pure geometry function) | request-response | itself — no code change required, only re-verification | n/a (verification-only touchpoint, not a pattern-copy site) |

## Pattern Assignments

### `Islet/Notch/NotchWindowController.swift` — `quickActionPickerFrame` reservation (~line 1023-1025)

**Analog:** `trayFrame` in the same function, ~line 1003-1005 (and `weatherExpandedFrame`, ~line 1016-1018, as a second confirming example of the same idiom)

**Current code to replace** (~line 1019-1025):
```swift
// Phase 34 / TRAY-02 (geometry three-site rule) — reserve space for the Quick Action
// picker up front too, mirroring trayFrame/weatherExpandedFrame's precedent exactly. NO
// switcherRowHeight addend — the picker is a full-takeover blob that never shows the
// switcher row (D-01).
let quickActionPickerFrame = expandedNotchFrame(collapsed: collapsedFrame,
                                                 expandedSize: CGSize(width: expandedSize.width,
                                                                       height: NotchPillView.quickActionPickerContentHeight))
```

**Pattern to copy** — `trayFrame`'s exact shape (~line 1003-1005), which already computes width AND height from the Tray constants:
```swift
let trayFrame = expandedNotchFrame(collapsed: collapsedFrame,
                                   expandedSize: CGSize(width: NotchPillView.traySize.width,
                                                         height: NotchPillView.trayContentHeight + NotchPillView.switcherRowHeight))
```

**What to change:** Replace `expandedSize.width` → `NotchPillView.traySize.width` (D-04), and replace `NotchPillView.quickActionPickerContentHeight` → `NotchPillView.trayContentHeight + NotchPillView.switcherRowHeight` (D-05, full Tray footprint including switcher-row space, even though the picker itself never shows the switcher row — this is a reservation-only change, matches trayFrame's own value verbatim). Update or delete the stale "NO switcherRowHeight addend" comment since D-05 now explicitly adds it to the *reservation* (the view's `showSwitcher: false` stays unchanged per D-06/D-15 — see below).

---

### `Islet/Notch/NotchWindowController.swift` — `contentSize` branch for `.quickActionPicker` (~line 1386-1392)

**Analog:** `.trayExpanded` branch in the same if/else-if ladder (~line 1371-1373)

**Current code to replace** (~line 1386-1392):
```swift
} else if case .quickActionPicker = presentationState.presentation {
    // Phase 34 / TRAY-02 (CR-01 geometry three-site rule) — must mirror
    // positionAndShow's quickActionPickerFrame reservation and NotchPillView's
    // quickActionPickerView height exactly, or the click-swallowing/dead-zone
    // regression class comes back. No switcherHeight addend (D-01 full-takeover,
    // no switcher row).
    contentSize = CGSize(width: expandedSize.width, height: NotchPillView.quickActionPickerContentHeight)
```

**Pattern to copy** — `.trayExpanded`'s exact shape (~line 1371-1373):
```swift
} else if case .trayExpanded = presentationState.presentation {
    contentSize = CGSize(width: NotchPillView.traySize.width,
                         height: NotchPillView.trayContentHeight + switcherHeight)
```

**What to change:** `expandedSize.width` → `NotchPillView.traySize.width`; height → `NotchPillView.trayContentHeight + NotchPillView.switcherRowHeight` (use the constant directly, NOT the local `switcherHeight` variable used by `.trayExpanded` — that local var is `switcherRowShowing ? switcherRowHeight : 0` and the picker's switcher row is never shown, so use the unconditional constant to match the reservation exactly, per D-05's explicit sum). Keep the CR-01 doc-comment discipline (this branch must mirror the reservation and the view's height 1:1, per the existing comment's own warning).

---

### `Islet/Notch/NotchPillView.swift` — `quickActionPickerView()` (~line 1471-1477)

**Analog:** `trayFullView` (~line 1399-1402) — the ONLY other `blobShape` caller in this file that passes both an explicit `width:` and `height:` override together

**Current code to replace** (~line 1471-1477):
```swift
private func quickActionPickerView() -> some View {
    blobShape(topCornerRadius: 24, bottomCornerRadius: 32, alignment: .top,
              height: Self.quickActionPickerContentHeight, shelfItems: [],
              shelfVisible: false, showSwitcher: false) {
        quickActionButtonRow()
            .padding(.top, Self.cameraClearance)   // camera/notch clearance — matches every other full-view
    }
}
```

**Pattern to copy** — `trayFullView`'s `blobShape` call signature (~line 1399-1402):
```swift
private var trayFullView: some View {
    blobShape(topCornerRadius: 24, bottomCornerRadius: 32, alignment: .top,
              width: Self.traySize.width, height: Self.trayContentHeight, shelfItems: [],
              shelfVisible: false, showSwitcher: true) {
        ...
    }
}
```

**Critical gotcha (do NOT literally copy `height: Self.trayContentHeight` alone):** `trayFullView` passes `showSwitcher: true`, so `blobShape`'s internal `totalHeight` computation (`baseHeight + (showSwitcher ? Self.switcherRowHeight : 0) + ...`, ~line 1853-1855) auto-adds `switcherRowHeight` on top of `trayContentHeight` for it — that's *why* `trayContentHeight` alone (145) is sufficient there. `quickActionPickerView()` keeps `showSwitcher: false` (D-06/existing D-01 comment — the switcher row must stay hidden), so `blobShape` will NOT auto-add that addend for the picker. Therefore the picker's `height:` argument must be passed as the **explicit sum** `Self.trayContentHeight + Self.switcherRowHeight` to land on the same `totalHeight` trayFullView reaches implicitly. This is exactly what D-05 specifies.

**What to change:**
```swift
private func quickActionPickerView() -> some View {
    blobShape(topCornerRadius: 24, bottomCornerRadius: 32, alignment: .top,
              width: Self.traySize.width, height: Self.trayContentHeight + Self.switcherRowHeight,
              shelfItems: [], shelfVisible: false, showSwitcher: false) {
        quickActionButtonRow()
            .padding(.top, Self.cameraClearance)
    }
}
```
(`showSwitcher: false` stays unchanged — D-06 — only `width:` is newly added and `height:` value changes.)

---

### `Islet/Notch/NotchPillView.swift` — `quickActionPickerContentHeight` constant (~line 727)

**Analog:** `calendarWidth`/`trayContentHeight` declaration style (~line 663-672) — single `static let` with a doc-comment box-math derivation directly above it

**Current code** (~line 722-727):
```swift
// Phase 34 (UAT revision, D-15) / 34-UI-SPEC.md §2 — the picker's content height, shrunk
// from 188 to 117 now that the preview block (D-14) and its 16pt section gap are gone. Only
// camera-clearance + the button row + a bottom inset remain:
//   cameraClearance(42) + buttonChip(icon 22 + gap 8 + label ~13 + vPadding 2x8 ~= 59)
//   + bottomInset(16) = 117.
static let quickActionPickerContentHeight: CGFloat = 117
```

**What to change (Claude's Discretion, per CONTEXT.md D-40/discretion note):** Two viable options, either is fine:
1. **Delete the constant outright** — both call sites (`NotchWindowController` line ~1025/1392, `NotchPillView` line ~1473) now reference `NotchPillView.trayContentHeight + NotchPillView.switcherRowHeight` directly instead, same as `trayFrame`/`.trayExpanded` do. Simplest, avoids a redundant single-use constant, matches the D-05 wording ("the picker's `height:` argument need[s] updating to this new value" — implying the value, not necessarily a renamed constant).
2. **Keep it as a named constant** with a new value/derivation comment (`= 189` = 145 + 44, with an updated box-math comment referencing `trayContentHeight + switcherRowHeight`) if a named constant reads better at the two call sites.
Either way, update/remove the stale "117" box-math comment — it documents the now-obsolete height.

---

## Shared Patterns

### The "geometry three-site rule" (already documented in-file, this phase's core constraint)
**Source:** `Islet/Notch/NotchWindowController.swift` ~line 1019 (comment on `quickActionPickerFrame`), reinforced at ~line 1386-1392 and `Islet/Notch/NotchPillView.swift`'s `blobShape` doc comments.
**Apply to:** All three touch points above — MUST be edited together in the same commit/task, in this exact order of dependency:
1. `NotchWindowController.positionAndShow()`'s `quickActionPickerFrame` reservation (panel-level union, sizes the AppKit window)
2. `NotchWindowController`'s `contentSize` branch for `.quickActionPicker` (hot-zone/click-through geometry)
3. `NotchPillView.quickActionPickerView()`'s `blobShape(...)` call (the actual SwiftUI-rendered size)

All three must agree pixel-for-pixel on width AND height, or the CR-01/CR-02-class click-swallowing/dead-zone regression returns (per `cr01-clickthrough-or-defeat-gotcha` project memory and D-08's explicit re-verification requirement).

### `blobShape`'s `width:`/`height:` optional override mechanism
**Source:** `Islet/Notch/NotchPillView.swift` ~line 1835-1867 (`private func blobShape<Content: View>(...)`)
**Apply to:** `quickActionPickerView()`'s edit above.
```swift
let baseWidth = width ?? Self.expandedSize.width
let baseHeight = height ?? (showSwitcher ? Self.switcherContentHeight : Self.expandedSize.height)
let totalHeight = baseHeight
    + (showSwitcher ? Self.switcherRowHeight : 0)
    + (hasShelf ? Self.shelfRowHeight : 0)
```
Key implication already worked out above: because the picker keeps `showSwitcher: false`, `switcherRowHeight` will NOT be auto-added by `blobShape` — it must be baked into the explicit `height:` argument instead (unlike `trayFullView`, which gets it for free via `showSwitcher: true`).

### `computeQuickActionButtonFrames` — no code change, re-verification only
**Source:** `Islet/Notch/DragDropSupport.swift` ~line 45-68
```swift
func computeQuickActionButtonFrames(card: CGRect) -> [CGRect] {
    let horizontalInset: CGFloat = 16
    let buttonRowHeight: CGFloat = 59
    let bottomInset: CGFloat = 16
    let gap: CGFloat = 16
    let rowRect = CGRect(x: card.minX + horizontalInset, y: card.minY + bottomInset,
                          width: card.width - 2 * horizontalInset, height: buttonRowHeight)
    let colWidth = (rowRect.width - 2 * gap) / 3
    return (0..<3).map { i in
        CGRect(x: rowRect.minX + CGFloat(i) * (colWidth + gap), y: rowRect.minY,
               width: colWidth, height: rowRect.height)
    }
}
```
This is a pure function of `card: CGRect` (the already-updated `quickActionPickerFrame`) — it needs NO code change; it will automatically compute correct button rects once `quickActionPickerFrame` grows. Per D-08, the plan must still include an explicit on-device re-verification step (hover→expand→drag→verify all 3 buttons are tappable at their new, more-centered position within the bigger card) — do not just assume the arithmetic "just works" without confirming on-device.

## No Analog Found

None — all 3 files have exact in-file precedent (`trayFrame`, `.trayExpanded` branch, `trayFullView`) already covering this file's own width+height override idiom.

## Metadata

**Analog search scope:** `Islet/Notch/NotchWindowController.swift`, `Islet/Notch/NotchPillView.swift`, `Islet/Notch/DragDropSupport.swift` (all analogs found within the same 3 files already named in CONTEXT.md — no broader codebase search was needed since this phase is a narrow constant-substitution fix with established in-file precedent)
**Files scanned:** 3
**Pattern extraction date:** 2026-07-19
