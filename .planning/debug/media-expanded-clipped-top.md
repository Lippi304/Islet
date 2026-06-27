---
status: awaiting_human_verify
trigger: "media-expanded-clipped-top: expanded Now-Playing media view top (album art + title) clipped above screen top edge; confirmed on-device via screenshot in 04-04 UAT"
created: 2026-06-27T21:34:02Z
updated: 2026-06-27T21:34:02Z
---

## Current Focus

hypothesis: CONFIRMED (2nd issue) — first fix (72→112) put content fully on-screen but content stayed top-anchored under the physical camera band because the island is pinned top-flush AND the overlay's centered ~84pt content in a 112pt blob left only ~14pt top clearance (< the 32pt notch band). Title rendered under the camera.
test: layout math — notch band 32pt (== wingsSize.height, measured notch on this machine) must be reserved EMPTY above content; content must top-pin not center.
expecting: raise expandedSize.height 112→128 (32 clearance + 84 content + 12 bottom) AND top-pin the overlay (.overlay(alignment:.top) + .padding(.top,32)/.bottom,12) so the island grows further and content starts exactly below the camera.
next_action: DONE — applied, build SUCCEEDED, 77/77 tests pass. Awaiting human on-device verify.

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

- timestamp: 2026-06-28T00:00:00Z
  checked: on-device UAT of first fix (72→112) + re-read mediaExpanded overlay alignment + body top-pin (NotchPillView.swift:84 ZStack alignment:.top, :113-115 container frame, expandedNotchFrame y = collapsed.maxY - height)
  found: First fix made the layout fully on-screen, but the island is pinned TOP-FLUSH to the screen edge, so its top ~32pt sits UNDER the physical camera/notch band. The .overlay CENTERS its content; ~84pt content in a 112pt blob → only ~14pt top clearance. The album art + title "Emotions"/artist started at ~14pt → still under the camera, cut off. User requires: island must expand FURTHER (taller) AND content must START below the top 32pt (notch band height == wingsSize.height, the measured notch on this machine).
  implication: two-part fix — (1) grow the single source-of-truth height to fit a 32pt EMPTY top clearance + the 84pt content + a 12pt bottom inset = 128; (2) TOP-PIN the overlay content so the 32pt clearance is exact, not re-centered into a gap.

- timestamp: 2026-06-28T00:00:00Z
  checked: applied fix — expandedSize.height 112→128; mediaExpanded .overlay(...) → .overlay(alignment:.top){...}; vertical padding 10/10 → .padding(.top,32)+.padding(.bottom,12)
  found: xcodebuild -scheme Islet build SUCCEEDED. IsletTests 77/77 pass, 0 failures (geometry tests use local CGSize literals, unaffected by the constant change).
  implication: the island now grows to 128pt (expands further) and the media content begins exactly 32pt below the top edge, clearing the camera band. Awaiting human on-device confirm.

## Resolution

root_cause: TWO related layout faults, same single source of truth. (1) NotchPillView.expandedSize.height (72pt) was smaller than the mediaExpanded content; the centered overlay overflowed the top-flush blob off-screen. (2) After raising it, the island is pinned TOP-FLUSH so its top 32pt sits under the physical camera/notch band, and the overlay CENTERS its ~84pt content in the blob — leaving only ~14pt top clearance, so the album art + title still rendered under the camera and were cut off. The fix had to both grow the island FURTHER and reserve an exact 32pt empty top band.
fix: Two edits, both in NotchPillView.swift. (a) expandedSize.height 72 → 112 → 128: 128 = 32 (top notch/camera clearance, == wingsSize.height = the measured notch height on this machine) + 84 (content: HStack art 40 + spacing 6 + seek spacer 4 + spacing 6 + transport row 28) + 12 (bottom inset for the bottomCornerRadius:20 curve). The panel window (expandedNotchFrame) and the SwiftUI content frame both derive from this one constant, so the island actually grows taller (expands further), not just shifts content. (b) mediaExpanded overlay: .overlay(...) → .overlay(alignment: .top){...} and vertical padding 10/10 → .padding(.top,32) + .padding(.bottom,12) (+ unchanged .horizontal,14). Top-pinning makes the 32pt clearance exact instead of re-centering content into a gap, so the media content begins exactly below the camera band.
verification: Build SUCCEEDED (xcodegen generate && xcodebuild -scheme Islet -destination platform=macOS build). IsletTests 77/77 pass, 0 failures (geometry tests use local CGSize literals, unaffected by the constant). Awaiting human on-device confirm: expand island while music plays → island taller, art + title start below the camera (nothing cut off), transport row fully visible, bottom curve doesn't clip it.
files_changed: [Islet/Notch/NotchPillView.swift]
