---
status: awaiting_human_verify
trigger: "media-expanded-clipped-top: expanded Now-Playing media view top (album art + title) clipped above screen top edge; confirmed on-device via screenshot in 04-04 UAT"
created: 2026-06-27T21:34:02Z
updated: 2026-06-27T21:34:02Z
---

## Current Focus

hypothesis: CONFIRMED — mediaExpanded overlay content (~104pt) exceeds the 72pt expandedSize blob/window; centered overlay overflows ~16pt above the top-flush blob → clipped off-screen.
test: layout-math read of mediaExpanded VStack + container frame + expandedNotchFrame y-pin + grep all expandedSize consumers
expecting: raising Self.expandedSize.height (single source of truth) makes BOTH the panel window (via expandedNotchFrame) and the SwiftUI content frame grow together → content fits below the notch.
next_action: raise expandedSize.height 72 → 112, build, run tests

## Symptoms

expected: When the expanded island shows media controls, the whole layout (album art + title/artist on top, transport row below) sits fully visible BELOW the notch, nothing clipped.
actual: Top portion (album art + title "Allein sein" / artist "Ufo361") cut off above the screen's top edge; only the lower transport row comfortably visible. Layout looks too tall for its container.
errors: None — builds clean, 77 tests pass. Purely a visual/layout defect.
reproduction: Build + run Islet, play a track, click island to expand → media controls view. Top is clipped off-screen.
started: Introduced in Phase 4 plan 04-03 (the media expanded layout). Earlier expanded states (date/time, charging wings) fit the 72pt frame so were not clipped.

## Eliminated

(none — root cause confirmed on first hypothesis via layout math)

## Evidence

- timestamp: 2026-06-27T21:34:02Z
  checked: NotchPillView.swift:65 expandedSize + :108-110 container frame + :270-315 mediaExpanded
  found: expandedSize = 360x72 is the single seed. mediaExpanded draws a 72pt NotchShape blob and puts the layout in an .overlay. Overlay content height = .padding(.vertical,10)=20 + VStack spacing(6*2)=12 + HStack(art 40, alignment .top)=40 + seek spacer .frame(height:4)=4 + transport row(28pt buttons)=28 ≈ 104pt.
  implication: 104pt content centered in a 72pt overlay overflows ~16pt top + ~16pt bottom.

- timestamp: 2026-06-27T21:34:02Z
  checked: NotchGeometry.swift:64-68 expandedNotchFrame + NotchWindowController.swift:122,264 + :108-110 view frame
  found: window y = collapsed.maxY - expandedSize.height → blob top edge flush with screen top edge. Both the panel window AND the .frame(height: expandedSize.height, alignment:.top) derive from the SAME expandedSize constant. The .overlay sizes content to the 72pt base and centers it.
  implication: the ~16pt top overflow renders ABOVE the screen → clipped. The 72pt window also cannot contain the 104pt content. Raising the ONE constant fixes both window + content together.

- timestamp: 2026-06-27T21:34:02Z
  checked: grep expandedSize across Islet + IsletTests
  found: consumers = NotchPillView (constant + container + expandedIsland/mediaExpanded/mediaUnavailable frames + 8 #Preview frames), NotchGeometry.expandedNotchFrame param, NotchWindowController.expandedSize seed. IsletTests/NotchGeometryTests uses a LOCAL literal CGSize(360,72), NOT the static constant.
  implication: changing the constant grows all expanded states + window consistently; the geometry tests are independent (local literals) so they stay green. expandedIsland (date/time) and mediaUnavailable center their small content so they remain correct, just modestly taller.

## Resolution

root_cause: NotchPillView.expandedSize.height (72pt) is smaller than the mediaExpanded overlay content's intrinsic height (~104pt). Because the panel window is pinned top-flush (expandedNotchFrame y = collapsed.maxY - height) and the overlay centers oversize content, the top ~16pt of the media layout (album art + title) overflows above the screen's top edge and is clipped. Date/time + charging states were unaffected because their content fits within 72pt.
fix: Raise NotchPillView.expandedSize.height from 72 to 112 (single source of truth at NotchPillView.swift:65). 112 = ~104pt content + ~8pt breathing room for the bottomCornerRadius:20 curve. Window frame (expandedNotchFrame) and the SwiftUI content frame both derive from this one constant, so they grow together; the media layout then sits fully below the notch, nothing clipped.
verification: Build SUCCEEDED (xcodebuild -scheme Islet -destination platform=macOS). IsletTests 77/77 pass, 0 failures (geometry tests use local literals, unaffected). Awaiting human on-device confirm: expand island while music plays → full layout visible/centered below notch, nothing clipped.
files_changed: [Islet/Notch/NotchPillView.swift]
