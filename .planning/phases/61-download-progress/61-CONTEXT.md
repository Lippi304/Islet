# Phase 61: Download-Progress - Context

**Gathered:** 2026-07-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Dropping a file into ~/Downloads shows a live "downloading" indicator in the collapsed notch that clears to a brief "done" state on completion. This phase builds the milestone's first genuinely new file-watching subsystem (FSEvents watching ~/Downloads) — no reskin, no prior pattern to clone in this codebase. It plugs into the Settings-grid card and default-OFF wiring Phase 59 already built, and slots into the same `IslandResolver`/`TransientQueue` collapsed-HUD architecture Phase 60 just proved with Caps Lock/Update. Multi-percentage progress across all browsers is explicitly NOT guaranteed — presence + completion signal only, per DL-01/DL-02.

</domain>

<decisions>
## Implementation Decisions

### Queue Placement & Persistence
- **D-01:** Download-Progress ranks **5** in `TransientQueue` (`Islet/Notch/IslandResolver.swift`) — above Caps Lock and Update-Available (which shift to rank 6/7), below OSD (rank 4). Rationale: an active download reads as real ongoing work, more urgent than a lightweight caps-lock toggle or update ping.
- **D-02:** The collapsed HUD stays visible for the **full download duration, no display-time cap** — tied to the temp file's actual presence, not a fixed timer.
- **D-03:** **Collapsed-only** — falls through unmodified when `isExpanded`, matching the Focus/OSD/Caps-Lock/Update precedent (`IslandResolver.swift:166-168`).
- **D-04:** A user's manual expand gesture **cuts the "done" splash short immediately** — matches the existing Charging/Device precedence (D-11 in Phase 3/6: user gesture always wins over a transient splash).

### Concurrent Downloads
- **D-05:** If two genuinely different files download at once (not the same file's own temp-rename sequence), the HUD shows **only the most recently started one**; the older download's own "done" state still fires independently later when it actually finishes.
- **D-06:** Tracking is **per-file** — each temp file is its own logical download, matching DL-01/DL-02's "each detected as one logical download apiece" wording (SC3).
- **D-07:** Only **~/Downloads** is watched — no per-browser custom download-folder configuration.
- **D-08:** No filtering beyond the known temp-file suffixes (`.crdownload`/`.download`/`.part`) — matching suffix alone is enough; everything else is silently ignored.

### HUD Content & Visuals
- **D-09:** In-progress label is a **generic "Downloading…" string**, not the filename — avoids truncation/overflow edge cases with long or unusual filenames.
- **D-10:** Trailing indicator is a **simple spinner icon**, not a pulsing/indeterminate bar.
- **D-11:** **No tap action** — purely informational, matching every other collapsed HUD (Charging/Device/Focus/OSD/Caps-Lock/Update).
- **D-12:** The **"done" state shows the actual final filename + a checkmark/done icon** — deliberately asymmetric with D-09: the in-progress label stays generic (temp filenames can be long/ugly), but once renamed to its final name the filename is stable and short, so it's worth surfacing there.

### Done-State Timing
- **D-13:** Done confirmation shows for **~3s**, matching the Charging/Device shared auto-dismiss-timer convention (not OSD's shorter 1.5s).
- **D-14:** If the app wasn't running at the exact moment a temp file was renamed, that missed transition is **silently skipped** — no historical FSEvents replay for this feature's scope.
- **D-15:** A cancelled/failed download (temp file deleted without ever being renamed to its final name) **silently disappears with no done state** — matches DL-02's literal wording (done fires only on rename-to-final-name).

### Claude's Discretion
- Exact spinner styling/animation timing (SwiftUI system spinner vs. a small custom one) — low-stakes, pick whatever matches the wings pattern's existing trailing-element sizing.
- Internal `DownloadActivityState`/monitor class naming and file layout — no user-facing impact.

### Reviewed Todos (not folded)
- `2026-07-19-calendar-month-grid-polish.md`, `2026-07-19-island-briefly-disappears-during-click-through.md`, `2026-07-19-quick-action-disabled-state-has-no-controller-gate.md` — surfaced by keyword match (`notch`, `phase`) but none are substantively about downloads or file-watching; reviewed and left out of this phase's scope.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap & Requirements
- `.planning/ROADMAP.md` §Phase 61: Download-Progress — Goal, SC1-4, depends on Phase 59
- `.planning/REQUIREMENTS.md` §v1.10 Requirements — Live Activities Suite § Download-Progress — DL-01, DL-02

### Prior phases (prerequisites this phase builds on)
- `.planning/phases/59-settings-redesign/59-CONTEXT.md` — the Settings-grid card model; `downloadProgressKey` is already wired (default OFF), this phase only reads it
- `.planning/phases/60-caps-lock-hud-update-activity-restyle/60-CONTEXT.md` — sibling collapsed-HUD precedent (wings pattern, rank-placement decision shape, collapsed-only mechanism) this phase's D-01/D-03 directly follow

### Resolver / priority
- `Islet/Notch/IslandResolver.swift:82-87` — the reserved forward-looking comment block explicitly flagging "Download Progress (Phase 61) — rank TBD — confirm in that activity's own phase discussion"; this phase's D-01 resolves it
- `Islet/Notch/IslandResolver.swift:94-117` — `IslandPresentation`/`ActiveTransient` enums, named-rank-comment convention
- `Islet/Notch/IslandResolver.swift:166-168` — collapsed-only fallthrough mechanism
- `Islet/Notch/IslandResolver.swift:277-375` — `TransientQueue` struct (head/pending/maxDepth)

### Settings wiring (already done, Phase 59)
- `Islet/ActivitySettings.swift` — `downloadProgressKey` constant, already included in `defaultsToFalseKeys` (default OFF)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Islet/Notch/NotchPillView.swift:2355-2395` (`wings(for:)`) — leading-icon+label / `Spacer()` / trailing-element shape to replicate for the download HUD (generic label + trailing spinner)
- `Islet/Notch/NotchPillView.swift:2721` (`osdWings(for:)`) — nearest existing self-elapsing, collapsed-only precedent
- `Islet/ActivitySettings.swift` — `downloadProgressKey` already exists and is already in `defaultsToFalseKeys`; no new Settings work needed this phase beyond reading it

### Established Patterns
- Named-rank-comment convention in `TransientQueue`/`IslandPresentation`/`ActiveTransient` — the new `.downloadProgress` case slots in at rank 5 per D-01; the existing Caps-Lock/Update-Available comments shift to rank 6/7
- Separate `@Published` state-holder model per activity (`ChargingActivityState.swift`'s "Pattern 2") — likely shape for a `DownloadActivityState`
- Every prior monitor class (`CapsLockMonitor`, `FocusModeMonitor`, `PowerSourceMonitor`) follows a start()/stop()/`nonisolated deinit` lifecycle skeleton — worth mirroring for the new file-watcher class even though its underlying mechanism (FSEvents) is net-new

### Integration Points
- **No existing FSEvents or general file-watcher code anywhere in this codebase** — grepping for `fsevents`, `filewatcher`, `filemonitor` across all `.swift` files returns nothing; `dispatchsource` hits exist (`ClipboardMonitor`, `FocusModeMonitor`, `CalendarCountdownMonitor`) but none watch the filesystem. This is genuinely the milestone's first file-watching subsystem — research should evaluate `FSEventStreamCreate` (Core Services) vs. `DispatchSource.makeFileSystemObjectSource` as the two real implementation options, with no in-codebase precedent to lean on either way.
- `Islet/Notch/CapsLockMonitor.swift` is the most recently built "OS-signal → onChange callback" monitor and is worth reading for its lifecycle shape (health-check timer re-arm, Accessibility-gate pattern) even though its trigger mechanism doesn't transfer.

</code_context>

<specifics>
## Specific Ideas

- The in-progress and done labels are intentionally asymmetric: generic "Downloading…" while active (temp filenames can be long/ugly), but the real, final filename once the temp file is renamed and the "done" checkmark shows (D-09/D-12).
- Visually, the download HUD should read as "the wings pattern, with a spinner instead of a battery/version pill" — no new shape, only new content.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. (See Reviewed Todos above for matches considered and left out.)

</deferred>

---

*Phase: 61-Download-Progress*
*Context gathered: 2026-07-23*
