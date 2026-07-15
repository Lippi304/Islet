---
phase: quick-260715-vsd
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - Islet/Notch/NotchPillView.swift
  - Islet/Notch/NotchWindowController.swift
autonomous: false
requirements: []
user_setup: []

must_haves:
  truths:
    - "The Now Playing expanded view (mediaExpanded) shows a visibly smaller gap between the transport-button row and the switcher-icon row below it, with the switcher row's own screen position unchanged relative to every other switcher-row presentation (Home/Tray/Calendar/Weather)."
    - "The Tray empty state's 'No files yet' title + subtitle text sits ~5pt further from the tray icon above it; the tray icon and the switcher-row icons below keep their exact existing position/size."
    - "The Calendar view's '+ Add' button renders and is clickable fully inside the island's visible black shape, with no part extending past the right edge."
    - "No other presentation (Home, Tray non-empty, Weather, onboarding, charging/device wings) changes size, position, or click-through behavior."
  artifacts:
    - path: "Islet/Notch/NotchPillView.swift"
      provides: "mediaExpanded bottom-padding increase; trayEmptyState nested-VStack spacing; new calendarWidth constant + isCalendarPresentation + calendarFullView width override/scaleEffect"
      contains: "calendarWidth"
    - path: "Islet/Notch/NotchWindowController.swift"
      provides: "visibleContentZone() calendarExpanded branch mirroring the new calendarWidth (geometry three-site rule)"
      contains: "calendarExpanded"
  key_links:
    - from: "NotchPillView.calendarFullView"
      to: "NotchPillView.calendarWidth"
      via: "blobShape(..., width: Self.calendarWidth, ...)"
      pattern: "width: Self\\.calendarWidth"
    - from: "NotchWindowController.visibleContentZone()"
      to: "NotchPillView.calendarWidth"
      via: "contentSize branch for .calendarExpanded"
      pattern: "NotchPillView\\.calendarWidth"
---

<objective>
Three small, unrelated cosmetic spacing/sizing fixes to the expanded island, reported by the
user from on-device screenshots. No behavior/logic changes — pure spacing constants and one
width override, following this file's own established "single named constant, tuned in
place" convention.

1. Now Playing expanded view: shrink the empty gap between the transport-button row and the
   switcher-icon row below it.
2. Tray empty state: add ~5pt more vertical space between the tray icon and the "No files
   yet" text block below it (icon position itself must not move).
3. Calendar view: the "+ Add" button pokes out past the island's right edge — widen the
   calendar-specific box and scale its content down 4% so the button lands fully inside the
   visible shape, and stays clickable (the click-through hit-zone must be updated in lockstep
   per this codebase's own documented "geometry three-site rule").

Purpose: three on-device UI polish issues the user hit while using the app.
Output: `Islet/Notch/NotchPillView.swift` (all three fixes) and
`Islet/Notch/NotchWindowController.swift` (fix 3's click-through zone update) edited in place.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md

<interfaces>
<!-- Exact current code the executor needs — extracted from the codebase, no exploration needed. -->

Islet/Notch/NotchPillView.swift — `mediaExpanded(_:art:)`, the fix-1 target. The content
closure passed to `blobShape` (topCornerRadius: 24, bottomCornerRadius: 32, alignment: .top,
showSwitcher: true, no `width:`/`height:` override — falls back to `Self.expandedSize.width`
/ `Self.switcherContentHeight` = 196pt). Structure (~line 1868-1927):
a VStack(spacing: 6) holding the art/title/artist/EqualizerBars HStack, then `ProgressBar`,
then the transport-button HStack, followed by `.padding(.top, Self.cameraClearance)` (42) and
`.padding(.bottom, 12)`, then `.frame(maxWidth: 322)`. Because the content's own intrinsic
height (~158pt: 42 top clearance + 40 art row + 6 spacing + 20 progress bar + 6 spacing + 32
transport row + 12 bottom padding) is shorter than the shared 196pt box it's placed in with
`alignment: .top`, ~38pt of empty space sits between the transport row and where the switcher
row (appended by `blobShape` itself, immediately below the content's fixed-height frame)
starts. `Self.switcherContentHeight` is a single constant shared by every switcher-row
presentation (Home/Tray/Calendar/Weather/NowPlaying) specifically so the switcher row's
on-screen Y position never differs between tabs — a documented, previously-fixed misclick bug
(28-04 round 5) — so this constant itself, and `mediaExpanded`'s own box height, must NOT
change. The only thing this fix touches is the existing `.padding(.bottom, 12)` value.

Islet/Notch/NotchPillView.swift — `trayEmptyState` (~line 1054-1069), the fix-2 target,
verbatim current body:
`VStack(spacing: 4) { Image(systemName: "tray")...; Text("No files yet")...; Text("Drag files
onto the notch to add them here.")...multilineTextAlignment(.center) }.padding(.top,
24).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)`
A single `spacing: 4` currently applies uniformly between all three children (icon→title AND
title→subtitle).

Islet/Notch/NotchPillView.swift — `calendarFullView` (~line 600-625), the fix-3 target.
Current `blobShape` call passes no `width:` override (falls back to `Self.expandedSize.width`
= 420) and no `height:` override (falls back to `Self.switcherContentHeight` = 196, since
`showSwitcher: true`). Content: `HStack(spacing: 0) { monthGridColumn; Rectangle()-divider;
dayListColumn.frame(maxWidth: .infinity, alignment: .top) }.padding(.horizontal,
16).padding(.top, Self.cameraClearance)`. `dayListColumn` (~line 702-723) right-aligns the
"+ Add" trigger (`QuickAddPopover`, a private struct at ~line 2137) via
`HStack { Spacer(); QuickAddPopover(onSubmit: onQuickAdd) }` as its first child — this is what
renders closest to the box's right edge. `NotchShape`'s side walls curve inward at a CONSTANT
24pt inset from each edge regardless of panel width (this file's own documented convention,
also the reason `mediaExpanded` caps its own content to `.frame(maxWidth: 322)` — see Quick
task 260714-3k6 round 2 comment near line 1914); the calendar content's current
`.padding(.horizontal, 16)` is 8pt short of that 24pt clearance, which is the root cause of
the Add button rendering into/past the curved wall region.

Islet/Notch/NotchPillView.swift — the two existing sibling boolean computed vars to mirror
(~line 48-57):
`private var isOnboardingPresentation: Bool { if case .onboarding = presentation { return
true }; return false }`
`private var isTrayPresentation: Bool { if case .trayExpanded = presentation { return true };
return false }`

Islet/Notch/NotchPillView.swift — `body`'s outer `.frame` width/height ternary (~line
500-507), the fix-3 site that must gain a calendar branch (mirrors the exact
`isTrayPresentation ? Self.traySize.width : (...)` pattern already used for Tray/onboarding):
`.frame(width: isTrayPresentation ? Self.traySize.width : (isOnboardingPresentation ?
Self.onboardingSize.width : Self.expandedSize.width), height: isTrayPresentation ? ... : (...),
alignment: .top)`
Only the WIDTH branch needs a calendar case — the height branch already resolves calendar
correctly today (`showsSwitcherRow` is true for `.calendarExpanded`, giving
`Self.switcherContentHeight + Self.switcherRowHeight`, which is not changing).

Islet/Notch/NotchWindowController.swift — `visibleContentZone()` (~line 1131-1182), the
fix-3 click-through site. Existing pattern for a presentation-specific content-size branch
(mirror this exactly for `.calendarExpanded`, inserted before the final `else`):
`} else if case .weatherExpanded = presentationState.presentation { ... contentSize =
CGSize(width: expandedSize.width, height: (...) + switcherHeight) } else { contentSize =
CGSize(width: expandedSize.width, height: (switcherRowShowing ? NotchPillView.
switcherContentHeight : expandedSize.height) + switcherHeight) }`
`switcherHeight` is already computed above this if/else chain as
`switcherRowShowing ? NotchPillView.switcherRowHeight : 0`. Today `.calendarExpanded` falls
into the final `else`, using `expandedSize.width` (420) — this is the exact geometry
mismatch fix 3 must correct once the SwiftUI content itself renders wider.

Islet/Notch/NotchWindowController.swift — `positionAndShow()`'s panel-frame union (~line
829-873): `panelFrame = expandedFrame.union(wings).union(onboardingFrame).union(trayFrame)
.union(weatherExpandedFrame).union(quickActionPickerFrame)`, where `trayFrame` already
reserves `NotchPillView.traySize.width` (650pt) and `expandedFrame` already reserves
`NotchPillView.switcherContentHeight + NotchPillView.shelfRowHeight +
NotchPillView.switcherRowHeight` (296pt) — both already exceed what fix 3's new calendar box
needs (460pt wide, 240pt tall). Every one of these frames shares the same anchor (`topPinnedFrame`
in NotchGeometry.swift centers each on `collapsed.midX` and pins each to `collapsed.maxY`), so
their `CGRect.union` already covers a wider-and-taller calendar box for free — this function
does NOT need a new union member for fix 3.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Shrink the Now Playing expanded gap</name>
  <files>Islet/Notch/NotchPillView.swift</files>
  <action>
In `mediaExpanded(_:art:)`, change the content VStack's existing `.padding(.bottom, 12)` to
`.padding(.bottom, 40)`. This is the sole change: it grows the content's own intrinsic height
from ~158pt to ~186pt within the still-196pt `switcherContentHeight` box (alignment stays
`.top`, box height stays untouched), shrinking the empty gap between the transport-button row
and the switcher-icon row from ~38pt to ~10pt. Update the padding line's inline comment to
note the new value shrinks the switcher-row gap (was sized only for "room for the
bottomCornerRadius:20 curve").

Do NOT touch `Self.switcherContentHeight`, `Self.cameraClearance`, the VStack's internal
`spacing: 6`, or `blobShape`'s call in `mediaExpanded` (no `height:` override) — any of those
would shift the switcher row's Y position, which must stay identical across every
switcher-row presentation (Home/Tray/Calendar/Weather/NowPlaying) to avoid reintroducing the
28-04-round-5 misclick regression documented at `Self.switcherContentHeight`'s own doc
comment.

Do NOT touch `mediaUnavailable` or `homeEmptyState` — the user's screenshot and description
are specifically about the healthy playing/paused Now Playing view (`mediaExpanded`), not
those sibling cases.
  </action>
  <verify>
    <automated>xcodebuild build -scheme Islet -destination 'platform=macOS' -configuration Debug 2>&1 | tail -5 | grep -q "BUILD SUCCEEDED"</automated>
  </verify>
  <done>
`xcodebuild build -scheme Islet` reports BUILD SUCCEEDED. `mediaExpanded`'s content padding
is `.padding(.bottom, 40)`. No other constant in the file changed.
  </done>
</task>

<task type="auto">
  <name>Task 2: Add breathing room in the Tray empty state</name>
  <files>Islet/Notch/NotchPillView.swift</files>
  <action>
In `trayEmptyState`, restructure the single `VStack(spacing: 4) { Image...; Text("No files
yet")...; Text("Drag files onto the notch...")... }` into two nested VStacks so only the
icon-to-text gap grows: an outer `VStack(spacing: 9)` holding the `Image(systemName: "tray")`
view followed by an inner `VStack(spacing: 4) { Text("No files yet")...; Text("Drag files onto
the notch to add them here.")... }`. This raises the icon→text-block gap from 4pt to 9pt
(+5pt, per the user's exact request) while the title→subtitle gap inside the inner VStack
stays 4pt, unchanged. Leave `.padding(.top, 24)` and the outer
`.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)` exactly as they are — the
icon's own position must not move.

Do NOT touch `homeEmptyState` — its own doc comment already notes it was "copied verbatim
from trayEmptyState's structure" but the user's request is scoped to the Tray tab only; do not
propagate this spacing change there.

Do NOT touch the switcher-icon row (`switcherRow`, appended by `blobShape` below this
content) — it is a separate view entirely and already unaffected by this change.
  </action>
  <verify>
    <automated>xcodebuild build -scheme Islet -destination 'platform=macOS' -configuration Debug 2>&1 | tail -5 | grep -q "BUILD SUCCEEDED"</automated>
  </verify>
  <done>
`xcodebuild build -scheme Islet` reports BUILD SUCCEEDED. `trayEmptyState` has an outer
`VStack(spacing: 9)` (icon + text block) wrapping an inner `VStack(spacing: 4)` (title +
subtitle). The tray icon's `.padding(.top, 24)` position is unchanged.
  </done>
</task>

<task type="auto">
  <name>Task 3: Widen the Calendar box and fit the Add button inside it</name>
  <files>Islet/Notch/NotchPillView.swift, Islet/Notch/NotchWindowController.swift</files>
  <action>
In `Islet/Notch/NotchPillView.swift`:

1. Add a new constant near `Self.onboardingSize`/`Self.traySize` (the existing per-presentation
size-override block): `static let calendarWidth: CGFloat = 460` (+40pt / ~9.5% over
`expandedSize.width`'s 420). Document why: the calendar content's own `.padding(.horizontal,
16)` is 8pt short of the 24pt wall-inset every `NotchShape` edge curves in at, and combined
with the 4% content scale-down below, the extra width gives the right-aligned "+ Add" trigger
enough real clearance from that curve.

2. Add a new computed var mirroring `isOnboardingPresentation`/`isTrayPresentation` exactly
(same file region, ~line 48-57): `private var isCalendarPresentation: Bool { if case
.calendarExpanded = presentation { return true }; return false }`.

3. In `body`'s outer `.frame` width ternary (~line 500), insert a calendar branch ahead of the
onboarding fallback: change `isTrayPresentation ? Self.traySize.width :
(isOnboardingPresentation ? Self.onboardingSize.width : Self.expandedSize.width)` to
`isTrayPresentation ? Self.traySize.width : (isCalendarPresentation ? Self.calendarWidth :
(isOnboardingPresentation ? Self.onboardingSize.width : Self.expandedSize.width))`. Leave the
height ternary on the following lines completely untouched — it already resolves calendar
correctly via `showsSwitcherRow`.

4. In `calendarFullView`'s `blobShape(...)` call, add `width: Self.calendarWidth` as an
explicit argument (alongside the existing `topCornerRadius`/`bottomCornerRadius`/`alignment`/
`shelfItems`/`shelfVisible`/`showSwitcher` arguments — `blobShape` already supports an optional
`width:` parameter, used today by `onboardingCarousel` and `trayFullView`). Then append
`.scaleEffect(0.96)` as the last modifier on the content closure, after the existing
`.padding(.top, Self.cameraClearance)` line (so it scales the whole padded HStack — month
grid, divider, and day list with its Add button — inward by 4% from its own center, pulling
the Add button further from the curved wall on top of the extra width from step 1).

In `Islet/Notch/NotchWindowController.swift`, inside `visibleContentZone()`: add a new
`else if case .calendarExpanded = presentationState.presentation` branch, inserted
immediately before the final `else` (same ordering convention as the existing
`.trayExpanded`/`.weatherExpanded`/`.quickActionPicker` branches above it), computing
`contentSize = CGSize(width: NotchPillView.calendarWidth, height:
NotchPillView.switcherContentHeight + switcherHeight)` (`switcherHeight` is already computed
earlier in the function). This keeps the click-through hit-zone in sync with the now-wider
rendered box — this codebase's own documented "geometry three-site rule" (view size / panel
reservation / click-zone must all agree, or clicks land where the box used to be).

Do NOT add a new union member to `positionAndShow()`'s `panelFrame` — `trayFrame` already
reserves 650pt of width and `expandedFrame` already reserves 296pt of height (both anchored
identically to a calendar box via the shared `topPinnedFrame` helper in NotchGeometry.swift),
comfortably covering the new 460×240 calendar need with zero panel resize. Adding a redundant
union member here would be dead code.
  </action>
  <verify>
    <automated>xcodebuild build -scheme Islet -destination 'platform=macOS' -configuration Debug 2>&1 | tail -5 | grep -q "BUILD SUCCEEDED"</automated>
  </verify>
  <done>
`xcodebuild build -scheme Islet` reports BUILD SUCCEEDED. `NotchPillView.calendarWidth` is
460. `calendarFullView`'s `blobShape` call passes `width: Self.calendarWidth` and its content
closure ends with `.scaleEffect(0.96)`. `body`'s outer frame width ternary has a calendar
branch. `NotchWindowController.visibleContentZone()` has a `.calendarExpanded` branch using
`NotchPillView.calendarWidth`. `positionAndShow()` is unchanged.
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>
Three cosmetic fixes: (1) the Now Playing expanded view's gap above the switcher-icon row is
shrunk from ~38pt to ~10pt; (2) the Tray empty state's "No files yet" text now sits ~5pt
further from the tray icon above it; (3) the Calendar view's "+ Add" button now renders (and
is click-through-correct) fully inside the island's right edge, via a wider calendar-specific
box + a 4% content scale-down.
  </what-built>
  <how-to-verify>
Open `Islet.xcodeproj` in Xcode and run the app on this Mac (Cmd-R, Debug scheme — no terminal
needed).

1. Play something in Spotify or Music, hover the notch to expand it. Confirm the gap between
   the transport-button row (⏪⏯⏩) and the 4 switcher icons (Home/Tray/Calendar/Weather)
   below it is noticeably smaller than before, without the transport buttons crowding the
   switcher row.
2. Switch to the Tray tab with no files dragged in yet ("No files yet" empty state). Confirm
   the tray icon's position looks unchanged, and the title/subtitle text sits with a visibly
   larger gap below the icon than before.
3. Switch to the Calendar tab. Confirm the "+ Add" button (top-right of the day-list column)
   renders fully inside the black island shape — no part of it extends past the right edge or
   sits under the curved corner. Click it to confirm the popover still opens (click-through
   still works at its new position).
4. Quickly switch between Home, Tray, Calendar, and Weather via the switcher pill a few times.
   Confirm the switcher-icon row itself never visibly jumps up/down between tabs, and no tab
   ever fails to register a click on the switcher pill (this is the project's own documented
   misclick regression class — confirm it's not reintroduced).
  </how-to-verify>
  <resume-signal>Type "approved" or describe any issue (e.g. "Add button still clipped", "switcher row jumped when switching tabs", "tray icon moved")</resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| None crossed | Pure UI geometry/spacing constants + one click-through hit-zone update; no new input parsing, no new external data, no new persisted state |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-vsd-01 | Denial of Service (local) | `NotchWindowController.visibleContentZone()`'s new `.calendarExpanded` branch | accept | Local-only, no attacker-controlled input; a stale/mismatched contentSize would only ever produce a UX bug (dead click zone), never a security issue — the Task 4 checkpoint's tab-switching trace explicitly re-verifies no click-through regression, matching this project's established CR-01 mitigation discipline |
</threat_model>

<verification>
- Build gate after each `auto` task: `xcodebuild build -scheme Islet -destination 'platform=macOS' -configuration Debug` -> BUILD SUCCEEDED (`xcodebuild test` is not used — see project memory `xcodebuild-test-headless-hang`).
- On-device checkpoint (final task) covers all three fixes plus a regression check on the switcher-row Y-position/click-through invariant these three fixes deliberately avoid disturbing.
</verification>

<success_criteria>
- `mediaExpanded`'s gap above the switcher row is visibly smaller, with `Self.switcherContentHeight` (and every other presentation's box height) unchanged.
- `trayEmptyState`'s text block sits ~5pt further from its icon; the icon's own position is unchanged.
- Calendar's "+ Add" button is fully inside the visible shape and remains clickable; `NotchWindowController.visibleContentZone()` agrees with the new width.
- No presentation other than Calendar/mediaExpanded/trayEmptyState changes size, position, or click-through behavior.
- User approves the on-device checkpoint.
</success_criteria>

<output>
Create `.planning/quick/260715-vsd-drei-kleine-ui-spacing-sizing-fixes-now-/260715-vsd-SUMMARY.md` when done
</output>
