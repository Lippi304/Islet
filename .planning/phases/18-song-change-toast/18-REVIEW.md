---
phase: 18-song-change-toast
reviewed: 2026-07-09T17:05:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - Islet/ActivitySettings.swift
  - Islet/Notch/IslandResolver.swift
  - Islet/Notch/NotchPillView.swift
  - Islet/Notch/NotchWindowController.swift
  - Islet/Notch/NowPlayingPresentation.swift
  - Islet/Notch/NowPlayingState.swift
  - Islet/SettingsView.swift
  - IsletTests/IslandResolverTests.swift
  - IsletTests/NowPlayingPresentationTests.swift
findings:
  critical: 0
  warning: 5
  info: 0
  total: 5
status: issues_found
---

# Phase 18: Code Review Report

**Reviewed:** 2026-07-09T17:05:00Z
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Reviewed the song-change toast feature: the pure seams (`songChangeToastGate`,
`songChangeToastContent`, `TrackToast`) in `IslandResolver.swift` /
`NowPlayingPresentation.swift` are well-tested and correctly implement the
documented D-01–D-04 suppression rules — traced every branch against the
resolver's own inputs and found the gate's two conditions (`activeTransient`,
`isExpanded`) can never disagree with `resolve()`'s own state, as claimed in
the file's header comment.

`NotchPillView.swift` and `NotchWindowController.swift` were checked
specifically for leftover artifacts from the 5 on-device iteration rounds
called out in the task: no dead code was found. The round-2 `toastSize`
constant, the standalone `songChangeToastView`, the old `mediaWings(_:art:)`,
and the superseded `blobShape(size:)` parameter are all fully gone — every
remaining reference to them is a historical comment, not live code. The panel
geometry math (`wingsFrame`/`expandedNotchFrame`, both top-pinned to the same
`collapsed.maxY`) was traced by hand and does correctly reserve enough
vertical space for the taller toast shape (64pt) inside the existing
144pt-tall expanded-frame union, so the panel is not under-sized.

What IS present is a set of smaller lifecycle/consistency gaps introduced
alongside the new toast state (`nowPlayingState.songChangeToast` +
`toastDismissWorkItem`) that don't mirror the discipline the rest of the
file already established for its sibling one-shot dismiss timers
(`dismissWorkItem`, `mediaDismissWorkItem`). None of these are crashes or
data-loss risks (the weak-self capture makes the missed `deinit` cancel
harmless), but they are real, traceable inconsistencies — not style
preferences.

## Warnings

### WR-01: Toast renders a dangling em dash when artist is empty

**File:** `Islet/Notch/NotchPillView.swift:360`
**Issue:** `toastTextRow` builds the toast string as a single interpolated
`Text("\(toast.title) — \(toast.artist)")`. `NowPlayingPresentation.swift`'s
`nowPlayingPresentation(from:)` maps a nil artist to `""` (line 57 of that
file), which is a normal, expected case (many Apple Music / Spotify tracks
report no artist). When that happens the toast renders as `"Song Title — "`
with a visible trailing dash and no text after it. `mediaExpanded` avoids
this exact problem by rendering title and artist as two separate `Text`
views instead of concatenating them.
**Fix:**
```swift
private func toastTextRow(_ toast: TrackToast) -> some View {
    let line = toast.artist.isEmpty ? toast.title : "\(toast.title) — \(toast.artist)"
    return Text(line)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(.white)
        .lineLimit(1)
        .truncationMode(.tail)
        .padding(.horizontal, 16)
        .frame(width: Self.wingsSize.width, height: Self.toastExtraHeight, alignment: .center)
}
```

### WR-02: Disabling "Now Playing" mid-toast doesn't clear the toast

**File:** `Islet/Notch/NotchWindowController.swift:896-904`
**Issue:** `handleSettingsChanged()`'s Now-Playing-disabled branch cancels
`mediaDismissWorkItem` and resets `presentation`/`artwork`/`position`, but
does not cancel `toastDismissWorkItem` or clear
`nowPlayingState.songChangeToast` — even though the very next block (908-913)
does exactly that for the dedicated `songChangeToastKey` toggle. Because
`currentPresentation()` forces `nowPlaying` to `.none` while the toggle is
off, the stale toast never renders in this state, but the field and its
in-flight 2s timer are left alive. If the user re-enables Now Playing within
that window, the stale toast can reappear even though no new song-change
event occurred.
**Fix:** Add the same clear used a few lines below:
```swift
} else if nowPlayingMonitor != nil {
    nowPlayingMonitor?.stop(); nowPlayingMonitor = nil
    mediaDismissWorkItem?.cancel()
    nowPlayingState.presentation = .none
    nowPlayingState.artwork = nil
    nowPlayingState.position = nil
    toastDismissWorkItem?.cancel()
    nowPlayingState.songChangeToast = nil
}
```

### WR-03: `toastDismissWorkItem` never cancelled in `deinit`

**File:** `Islet/Notch/NotchWindowController.swift:1122-1166`
**Issue:** Every other one-shot `DispatchWorkItem` owned by this controller
(`graceWorkItem`, `dismissWorkItem`, `mediaDismissWorkItem`,
`trialExpiryWorkItem`) is explicitly cancelled in `deinit`. `toastDismissWorkItem`
is the one exception — it's declared right alongside `mediaDismissWorkItem`
(line 164) and its own doc comment claims it "mirrors
`scheduleMediaDismiss`'s cancel-then-reschedule discipline exactly," but the
mirroring stops short of teardown. This doesn't crash (the closure captures
`self` weakly, so it becomes a harmless no-op after dealloc), but it's an
inconsistency a future maintainer will trip over when auditing "does every
work item get cancelled on teardown."
**Fix:**
```swift
nowPlayingMonitor?.stop()
mediaDismissWorkItem?.cancel()
toastDismissWorkItem?.cancel()
```

### WR-04: Toast auto-dismiss doesn't pause on hover, unlike its siblings

**File:** `Islet/Notch/NotchWindowController.swift:652-685` (`handleHoverEnter`), `703-739` (`handleHoverExit`)
**Issue:** `handleHoverEnter` explicitly cancels `dismissWorkItem` and
`mediaDismissWorkItem` "so the hover doesn't lose the splash" (D-10 /
Finding 7), and `handleHoverExit` resumes them. `toastDismissWorkItem` is
never touched by either method, so a toast that appears and is then hovered
over (to read it) can still vanish mid-hover on its fixed 2s timer, unlike
every other transient/glance in this codebase. This may be an intentional
simplification for a "passive toast," but it's inconsistent with the
established hover-pause discipline this same file applies everywhere else,
and is worth a deliberate decision rather than an implicit gap.
**Fix:** Either mirror the existing pattern (cancel in `handleHoverEnter`,
reschedule the remaining time in `handleHoverExit`), or leave a `ponytail:`-
style comment explaining the toast is deliberately hover-immune so the next
reader doesn't file this as a bug again.

### WR-05: No SwiftUI Preview for the new toast row

**File:** `Islet/Notch/NotchPillView.swift:802-931` (`#if DEBUG` preview block)
**Issue:** The file's own stated convention (line 803: "Build-time
correctness artifact: proves BOTH layouts compile and render without running
the app") gives every rendered state its own `#Preview` — collapsed,
expanded, charging wings, device wings, media wings playing/paused, media
expanded, unavailable. The toast row (`mediaWingsOrToast` with a non-nil
`songChangeToast`, the only new visual state this phase adds, and the one
that went through 5 rounds of on-device sizing iteration) has no matching
preview, so a future regression in its layout/sizing has no build-time
correctness check and would only be caught by another on-device pass.
**Fix:**
```swift
#Preview("Media Wings + Toast") {
    let state = NotchInteractionState()
    state.phase = .collapsed
    let np = NowPlayingState()
    np.presentation = .playing(title: "New Rules", artist: "Dua Lipa")
    np.songChangeToast = TrackToast(title: "New Rules", artist: "Dua Lipa")
    return NotchPillView(interaction: state,
                         nowPlaying: np,
                         presentationState: IslandPresentationState(.nowPlayingWings(.playing(title: "New Rules", artist: "Dua Lipa"))),
                         outfit: BasicOutfitState())
        .frame(width: NotchPillView.expandedSize.width,
               height: NotchPillView.expandedSize.height)
        .background(Color.gray.opacity(0.3))
}
```

---

_Reviewed: 2026-07-09T17:05:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
