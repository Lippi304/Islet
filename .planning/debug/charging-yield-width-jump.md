# Debug: charging-yield-width-jump

## Symptom
After a charging splash yields back to the Now-Playing wings, the transition is
an abrupt width resize with the media symbols (album art + equalizer bars)
popping in afterward — not a smooth width morph. User (German): "Die Beiden
breiten passen nicht also es ist nicht so schön das quasi beide Musik Symbole
verschwinden und das dann halt die notch breiter wird und dann tauchen da die
Symbole auf also kein smoother übergang." (the two widths don't match — both
music symbols disappear, then the notch widens, only then do the symbols
reappear.)

Reported only on the **yield-back** direction (charging → media wings). The
**entrance** direction (idle/media → charging splash, and the analogous
device-connect splash in UAT Test 2) was NOT flagged as broken.

## Status: ROOT CAUSE FOUND (diagnosis only — no fix applied)

## Root cause

`NotchWindowController.scheduleActivityDismiss()` (`Islet/Notch/NotchWindowController.swift:613-629`)
mutates an `@ObservedObject` the view is bound to **outside** the
`withAnimation` block that animates the actual presentation change:

```swift
private func scheduleActivityDismiss() {
    dismissWorkItem?.cancel()
    let work = DispatchWorkItem { [weak self] in
        guard let self else { return }
        _ = self.transientQueue.advance()             // (1) pure, no publish
        self.syncActivityModels()                      // (2) <-- publishes OUTSIDE any animation
        withAnimation(.spring(response: self.springResponse, dampingFraction: self.springDamping)) {
            self.renderPresentation()                  // (3) publishes presentationState — ANIMATED
        }
        self.updateVisibility()
        ...
    }
    ...
}
```

`syncActivityModels()` (`NotchWindowController.swift:634-640`):

```swift
private func syncActivityModels() {
    switch transientQueue.head {
    case .charging: deviceState.activity = nil
    case .device:   chargingState.activity = nil
    case nil:       chargingState.activity = nil; deviceState.activity = nil
    }
}
```

On a charging-splash timeout with no queued device transient, `head` becomes
`nil`, so this sets **`chargingState.activity = nil`** (line 638) — a mutation
to `ChargingActivityState.activity`, a plain `@Published var` on an
`ObservableObject` (`Islet/Notch/ChargingActivityState.swift:11`).

`NotchPillView` holds `@ObservedObject var charging: ChargingActivityState`
(`NotchPillView.swift:28`). SwiftUI re-evaluates a view's `body` whenever *any*
`@ObservedObject` it holds publishes a change — regardless of whether that
particular property is read by the currently-rendered switch case. Because
`chargingState.activity = nil` executes **before** the `withAnimation(.spring)`
block opens, it runs in the ambient (non-animated) transaction. This produces
an un-animated intermediate SwiftUI commit for `NotchPillView` sandwiched
between:
- the last-known state (`.charging(...)`, still true at that instant — the
  presentation enum hasn't changed yet), and
- the animated commit half a statement later that flips `presentationState`
  from `.charging(...)` to `.nowPlayingWings(...)`.

Two back-to-back transactions on the same view/`matchedGeometryEffect`
identity in the same run-loop turn — one with no animation, one wrapped in a
spring — is a known way to break `matchedGeometryEffect`'s frame
interpolation: the un-animated commit "settles" the geometry tracking, so the
following spring has no valid in-flight source frame to interpolate from and
SwiftUI falls back to an instantaneous frame snap for the shape, with the
differing overlay content (bolt+battery vs. art+equalizer) then swapping in
right after — exactly the "widens, then symbols pop in" sequence reported.

**This mechanism is asymmetric by construction**: `syncActivityModels()` is
called *only* from `scheduleActivityDismiss()` (the yield-back/advance path).
The entrance path (`handlePower` / `handleDevice`, `NotchWindowController.swift:580-594`,
`685-696`) never calls it — it goes straight from `enqueue(...)` into the
single `withAnimation { renderPresentation() }` call with no preceding
un-animated publish. That matches why UAT flagged only the yield-back
direction, not the initial charging-splash appearance or the device-connect
splash (Test 2, which only exercises the *entrance*, not what happens after
its ~3s auto-dismiss).

`deviceState.activity = nil` (also set in the `nil`-head branch) has no such
effect on this particular glitch — `NotchPillView` does not hold `deviceState`
as an `@ObservedObject` at all (its value only reaches the view indirectly,
via the resolver's `presentationState`), so that write is inert for this view.

## Ruled out

- **Shared `matchedGeometryEffect` namespace not covering all wing variants** —
  false. All seven render branches (`collapsedIsland`, `expandedIsland`,
  `wings(for:)`, `mediaWings(_:art:)`, `deviceWings(for:)`, `mediaExpanded`,
  `mediaUnavailable`) apply `.matchedGeometryEffect(id: "island", in: ns)`
  against the SAME `@Namespace private var ns` (`NotchPillView.swift:81`,
  used at lines 166, 181, 207, 234, 269, 376, 442). Namespace coverage is
  complete.

- **Raw width mismatch between the charging wing and the media wing** — false
  as of the current code, and was already fixed *before* this UAT session ran.
  `NotchPillView.wingsSize`, `.mediaWingsSize`, and `.deviceWingsSize` are all
  literally `CGSize(width: 290, height: 32)` (`NotchPillView.swift:114-116`,
  labeled "Post-checkpoint (user request): ONE uniform 290 pt width across all
  three wing glances"). Git history confirms this unification landed in
  `f319e69` "fix(06-04): wings width 290pt" at 2026-06-28 23:34, well before
  the UAT session (`.planning/phases/06-priority-resolver-settings-v1-ship/06-UAT.md`,
  started 2026-07-01T00:41:22Z per `06-UAT.md` frontmatter). So the SwiftUI
  content frame for charging wings and media wings is identical at the time of
  the report — the perceived "widths don't match" is a *symptom* of the
  transient mis-render below, not a static constant bug.

- **AppKit/NSPanel-level resize** — false. `NotchWindowController.wingsSize`
  (`NotchWindowController.swift:167`) is a single private constant
  (`NotchPillView.wingsSize`) used for ALL activities when computing
  `panelFrame` in `positionAndShow` (`NotchWindowController.swift:403-441`):
  `panelFrame = expandedFrame.union(wingsFrame(collapsed:, wingsSize:))`. This
  union is a fixed rectangle (the notch's expanded 360×128 footprint unioned
  with the 290×32 wings footprint) that never changes size across
  charging/media/device/idle activity switches — only the transparent
  SwiftUI content *within* that constant window resizes. The window itself is
  not the source of the visible jump.

- **Async artwork load causing a delayed "symbol pop-in"** — inconsistent with
  the report. `nowPlaying.artwork` loading in asynchronously would explain a
  delayed *album art* only (music-note placeholder → art), but the user
  reports *both* symbols (art AND equalizer bars) disappearing and reappearing
  together, and `EqualizerBars` has no dependency on the async artwork
  pipeline at all — this points to a full-view re-render/reset, not an
  artwork-specific late fetch.

## Contributing/secondary factor (same asymmetry, weaker signal)

`updateVisibility()` is called synchronously right after every
`withAnimation { renderPresentation() }` block (both on entrance and on
dismiss), and its `positionAndShow` path calls
`panel.setFrame(panelFrame, display: true)` even when `panelFrame`'s value is
unchanged. `display: true` forces an immediate AppKit redisplay outside the
SwiftUI/Core Animation transaction, which could compound an already-broken
interpolation from the primary cause above. This alone doesn't explain the
directional asymmetry (it fires symmetrically on entrance and exit), so it's
listed as a secondary/compounding factor, not the primary cause.

## Files involved
- `Islet/Notch/NotchWindowController.swift:613-640` — `scheduleActivityDismiss()` / `syncActivityModels()`: the un-animated `chargingState.activity = nil` write that precedes the animated `renderPresentation()` call (primary root cause)
- `Islet/Notch/NotchWindowController.swift:580-594`, `652-697` — `handlePower` / `handleDevice`: the entrance path, which has no equivalent pre-animation publish (why entrance is unaffected)
- `Islet/Notch/ChargingActivityState.swift:11` — `@Published var activity` that NotchPillView observes directly
- `Islet/Notch/NotchPillView.swift:28` — `@ObservedObject var charging: ChargingActivityState` (the observation that makes the un-animated write visible to this view)
- `Islet/Notch/NotchPillView.swift:81, 166, 181, 207, 234, 269, 376, 442` — the single shared `matchedGeometryEffect` namespace (confirmed complete, ruled out)
- `Islet/Notch/NotchPillView.swift:114-116` — the now-uniform 290×32 wing size constants (confirmed equal, ruled out)
- `Islet/Notch/NotchWindowController.swift:167, 403-441` — panel sizing math (confirmed constant across activities, ruled out)
- `.planning/phases/06-priority-resolver-settings-v1-ship/06-UAT.md` — Test 1 report + Gaps entry
- git commit `f319e69` (2026-06-28 23:34:56 +0200) "fix(06-04): wings width 290pt" — establishes the width unification pre-dates this UAT session
