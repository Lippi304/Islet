# Phase 27: Settings Sidebar Redesign - Context

**Gathered:** 2026-07-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Settings is restructured from today's 3-tab `TabView` (General / Appearance / Activities) into a `NavigationSplitView` sidebar with 4 sections: **General**, **Workspace (Shelf)**, **System (Theming)**, **About/License**. Every existing control (License section, Launch-at-login, Diagnostics, Version, Accent picker, Fullscreen toggle, 4 activity toggles) is preserved and functional in its new home — no functional regression. A new **Theming** capability (VISUAL-03, descoped from Phase 25) is added to the System section: a 2-preset material/surface style picker (Gradient / Solid Black) and independent per-element accent-color pickers (Now Playing / Charging / Device).

**App icon variant selection is explicitly OUT of this phase's scope** (see Decisions) — no alternate icon assets exist in the repo, and the user chose to descope that part of VISUAL-03/Success-Criterion-4 to a future phase rather than build placeholder icons now. Phase 27 does NOT touch: shelf functionality itself (Phase 24, already shipped), calendar/view-switcher (Phase 28), any individual activity's content rendering.

</domain>

<decisions>
## Implementation Decisions

### Section-to-control mapping
- **D-01 (LOCKED):** **General** section = the 4 activity toggles (Charging, Now Playing, Song-Change Toast, Devices) + Launch-at-login + the Fullscreen toggle ("Hide notch in fullscreen") + Diagnostics ("Save Diagnostic Report…" button). This is a deliberate catch-all — user explicitly chose to consolidate rather than invent a 5th "Activities" section not named in the ROADMAP's 4-section list.
- **D-02 (LOCKED):** **About/License** section = the existing adaptive License block (trial countdown / expired / licensed states, license-key entry, Buy Now button, status line) + the Version label. Matches the section name literally — nothing else moves here.
- **D-03 (LOCKED):** **Workspace (Shelf)** section is built as a real sidebar entry even though no shelf-specific settings exist today (no shelf toggle, no shelf preference anywhere in the codebase). It shows placeholder content (e.g., "No shelf settings yet") to literally satisfy ROADMAP Success Criterion #1 ("sidebar sections General, Workspace (Shelf), System (Theming), and About/License"). Exact placeholder copy is Claude's discretion.
- **D-04 (LOCKED):** **System (Theming)** section = the existing Accent picker (today's single global accent — see D-06 for how it changes) + NEW: material-style preset picker + per-element accent pickers.

### Theming — material/surface style (VISUAL-03, part 1)
- **D-05 (LOCKED):** Exactly **2 presets**: "Gradient" (Phase 25's existing black-to-transparent vertical gradient, VISUAL-01 — stays the default) and "Solid Black" (a flat `Color.black` fill, i.e. the pre-Phase-25 look, offered as a fallback/alternate style). No third "Glossy" preset — user explicitly picked the smaller 2-preset scope. Picker mechanism (segmented control, radio list, swatches) is Claude's/planner's discretion.
- **D-06:** Selecting a preset must apply to all 3 shell-chrome fill sites Phase 25 touched (`collapsedIsland`, `blobShape`, `wingsShape`, `mediaWingsOrToast` in `NotchPillView.swift`) — consistent across collapsed pill, expanded island, and wings, matching how Phase 25 itself applied the gradient everywhere at once.

### Theming — per-element accent colors (VISUAL-03, part 2)
- **D-07 (LOCKED):** The single global `accentIndexKey` accent picker is replaced by **3 independent pickers** — one each for Now Playing (equalizer bars), Charging (glyph), Device (battery icon) — each drawing from the same existing curated 6-swatch palette (`ActivitySettings.palette`). A user who wants the old uniform look just picks the same swatch in all three; no "linked/uniform mode" toggle requested.
- **D-08:** This requires 3 new `@AppStorage` keys (one per element) replacing the single `accentIndexKey`, and updating `ActivitySettings.accent(for:)`/`activityAccent` environment plumbing to be per-element rather than single-value — exact naming/migration approach (e.g., whether existing `accentIndexKey` value seeds all 3 on first read, to avoid every existing user's accent silently resetting to the default swatch) is Claude's/planner's discretion, but MUST avoid a silent visual regression for existing users on upgrade.

### App icon variants — explicitly descoped
- **D-09 (LOCKED):** No alternate app-icon assets exist anywhere in the repo (`brand/islet/AppIcon.appiconset` has exactly one icon set; `Islet/Assets.xcassets` has one `AppIcon`). Building "alternate app icon variants" would mean either the user supplying real designed icon files, or Claude generating placeholder tinted variants — user rejected both for this phase and chose to **cut the app-icon part of Success Criterion #4 from Phase 27 entirely**, deferring it to backlog/a future phase once real icon variants exist.
- **D-10 (Follow-up required, not yet applied):** Same pattern as Phase 25's D-04 (VISUAL-03 descope from Phase 25 → Phase 27). Before/at planning, `REQUIREMENTS.md`'s VISUAL-03 wording and `ROADMAP.md`'s Phase 27 Success Criterion #4 need a follow-up edit to drop "choose among alternate app icon variants," and a note should be added to the Deferred/Backlog tracking that app-icon selection remains open for a future phase. This CONTEXT.md does not edit those files itself.

### Claude's Discretion
- Exact SwiftUI mechanism for material-style preset picker and per-element accent pickers (segmented control vs. list vs. swatch grid) — visual layout is a planning/UI-phase decision, not discussed here.
- Settings window sizing — today's `SettingsView` is a fixed `.frame(width: 360, height: 280)`; a `NavigationSplitView` sidebar layout will very likely need a wider/taller frame. Exact dimensions are implementation/on-device-tuning judgment (this project's established pattern — Phase 18, Phase 20/21/23, Phase 26 all tuned dimensions on-device after initial implementation).
- Whether the `NavigationSplitView` uses a fixed always-visible sidebar or a collapsible one — technical choice, not discussed with the user.
- Exact placeholder copy for the empty Workspace (Shelf) section (D-03).
- Exact migration/seeding approach for the 3 new per-element accent keys (D-08) — must not visually regress existing users, but the specific UserDefaults read/write sequence is implementation detail.
- Whether "Solid Black" preset (D-05) needs its own bottom-corner-radius handling or reuses Phase 25's existing shape values unchanged — likely the latter (this phase changes fill/material only, not shape), but confirm during planning/research if Phase 25's `NotchShape` corner-radius values were coupled to the gradient in any way.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements source
- `.planning/REQUIREMENTS.md` line 30 — **SETTINGS-01**: sidebar restructure, existing toggles + accent picker preserved, no functional regression
- `.planning/REQUIREMENTS.md` line 26 — **VISUAL-03**: Theming section (material/surface style, per-element accent colors, app icon variants) — **this phase drops the app-icon-variants portion per D-09/D-10; REQUIREMENTS.md itself has not yet been edited to reflect this and needs a follow-up pass before/at planning, same pattern as Phase 25's own VISUAL-03 descope note**
- `.planning/ROADMAP.md` §"Phase 27: Settings Sidebar Redesign" (lines 370-381) — Goal, Depends on (none), 4 Success Criteria (Criterion #4's "alternate app icon variants" clause is affected by D-09/D-10's descope)

### Prior-phase decisions this phase builds on
- `.planning/phases/25-visual-material-theming-redesign/25-CONTEXT.md` D-04 — the original decision that deferred VISUAL-03 to "a future phase (candidate home: Phase 27 Settings Sidebar Redesign)" — confirms this phase is the intended landing spot for the Theming section.
- `.planning/phases/25-visual-material-theming-redesign/25-CONTEXT.md` §"Existing code this phase modifies" — the 4 fill sites in `NotchPillView.swift` (`collapsedIsland`, `blobShape`, `wingsShape`, `mediaWingsOrToast`) that D-06 (this phase) requires the Solid-Black preset to also apply to.
- `.planning/phases/26-onboarding-flow/26-CONTEXT.md` D-07 — `NotchPanel.canBecomeKey`/`canBecomeMain` hard-locked `false`; irrelevant to this phase directly (Settings is already the focusable window) but confirms Settings remains the one focusable surface in the app, relevant if Theming controls ever needed live notch-panel preview (not requested here).

### Existing code this phase modifies
- `Islet/SettingsView.swift` — the entire `TabView` body (lines 40-160) is restructured into a `NavigationSplitView`. Specific existing blocks to relocate: License `Section` (lines 48-65) + Version (lines 94-96) → About/License; Launch-at-login toggle (lines 67-86) + Diagnostics `Section` (lines 90-92) + the 3 Activities toggles (lines 134-139) + Fullscreen toggle (lines 124-126) → General; Accent picker (lines 100-120) → System (Theming), replaced per D-07.
- `Islet/ActivitySettings.swift` — `accentIndexKey` (single global key, line 27) and `accent(for:)` (lines 37-39) / `activityAccent` environment plumbing (lines 47-56) need to become 3 per-element keys/lookups per D-07/D-08. `palette`/`defaultAccentIndex` (lines 30-31) stay unchanged — same swatches, just applied 3x independently.
- `Islet/IsletApp.swift` lines 39-46 — the `Window("Islet Settings", id: "settings")` scene hosting `SettingsView()`; `.windowResizability(.contentSize)` (line 43) means the window auto-sizes to whatever frame `SettingsView` declares, so a wider `NavigationSplitView` frame (see Claude's Discretion) just works without scene-level changes.
- `Islet/NotchPillView.swift` — the 4 fill sites (`collapsedIsland`, `blobShape`, `wingsShape`, `mediaWingsOrToast`) that currently apply Phase 25's single gradient; D-05/D-06 require these to read a persisted material-style choice and branch between Gradient and Solid Black.

No other external specs — requirements fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ActivitySettings.palette` (6-swatch curated array) — reused as-is for all 3 new per-element pickers (D-07), no new color infrastructure needed.
- The existing adaptive License `switch` block in `SettingsView.swift` (trial/trialExpired/licensed) — moves wholesale into the About/License section, no logic changes.
- `Islet/NotchPillView.swift`'s 4 fill sites — already the single integration point Phase 25 established; this phase adds a style-choice branch at the same sites rather than introducing new ones.

### Established Patterns
- **`@AppStorage` as source of truth for app-owned prefs** (D-09 from Phase 6/APP-03, reconfirmed in `ActivitySettings.swift`'s own header comment) — the new material-style key and the 3 per-element accent keys follow this same idiom, not a new persistence mechanism.
- **On-device iterative tuning is normal in this project** (Phase 7, 18, 20/21/23, 25, 26 UAT rounds) — window sizing and exact preset-picker layout are expected to be tuned after first implementation, not fully pre-specified.
- **"Descope with a follow-up-edit note, never silently drop"** — this project's established convention (Phase 25 D-04 for VISUAL-03) — this phase's D-09/D-10 follows the identical pattern for the app-icon portion.

### Integration Points
- `SettingsView.swift`'s single `body` is the only integration point for the sidebar restructure — no other file references the tab structure directly.
- `ActivitySettings.swift` is the shared key namespace between `SettingsView` and `NotchWindowController`/the activity views that read `activityAccent` — any per-element key rename must stay synced with whatever reads `activityAccent` today (Phase 6 Pattern 4, per the file's own header comment).

</code_context>

<specifics>
## Specific Ideas

- No new visual reference (Droppy) was shown for this phase — the 4-section sidebar naming (General/Workspace/System/About) comes directly from ROADMAP.md's own wording, not a fresh screenshot walkthrough.

</specifics>

<deferred>
## Deferred Ideas

- **Alternate app icon variants** — no icon assets exist yet; user explicitly deferred this to backlog/a future phase (D-09/D-10) rather than build placeholders now. When picked up later, needs either user-supplied icon files or a proper icon-design pass — not a Claude-generated placeholder.

</deferred>

---

*Phase: 27-Settings-Sidebar-Redesign*
*Context gathered: 2026-07-12*
