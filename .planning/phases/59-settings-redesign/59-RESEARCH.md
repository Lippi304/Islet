# Phase 59: Settings-Redesign - Research

**Researched:** 2026-07-23
**Domain:** SwiftUI Settings UI redesign (grid/card layout) + `@AppStorage` migration-safety + resolver documentation
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
### Grid Layout
- **D-01:** Cards are grouped into fixed categories with visible headers: **System-HUDs**, **Medien**, **Produktivität** — not a flat list, not alphabetical.
- **D-02:** Grid is fixed at **2 columns** (not 3, not adaptive/responsive) — matches the current fixed-width Settings window.
- **D-03:** Within each category, already-shipped activities are ordered before new v1.10 activities.
- **D-04:** New (v1.10-introduced) activities' cards carry a visible **"Neu"-Badge** to help users discover them, since they're defaulted OFF and could otherwise go unnoticed.

### Grid Contents & Categorization
- **D-05:** "Launch at login" and "Automatically Check for Updates" are **not** cards in the grid — they stay as plain toggles in a separate general/non-activity section, since they produce no island content.
- **D-06:** "Song-Change Toast" gets **its own card** (not folded as a sub-option under the "Now Playing" card), consistent with "one card per toggle."
- **D-07:** Category assignments for existing activities: **System-HUDs** = Charging, Device/Bluetooth, Focus Mode HUD, OSD-Suppression, Calendar Countdown. **Medien** = Now Playing, Song-Change Toast. **Produktivität** = reserved for new v1.10 activities (Timer/Pomodoro, Meeting-HUD, Quick Notes, Quick Actions bar).

### Card Options Affordance
- **D-08:** Focus Mode HUD's and OSD-Suppression's existing "+Popover" (extra config) stays attached to the card, not moved to a separate detail sheet.
- **D-09:** The card component gets a **generic, optional options-slot affordance** (icon/chevron) now, in Phase 59 — not deferred to whichever later phase first needs it. This is a deliberate foundation choice: later phases (Timer duration, Meeting-HUD calendar picker, etc.) fill the slot instead of redesigning the card.
- **D-10:** The new generic options-slot **replaces** today's separate "+Popover" icon on Focus Mode HUD / OSD-Suppression — one unified options icon across all cards, not two icons side by side.

### Mini Preview
- **D-11:** Card preview is a **static illustration icon** per activity (SF-Symbol-style, in the activity's pill color/shape) — explicitly NOT a live-updating real-data preview (no real battery %, no real album art). Rationale: matches the actual Droppy reference grid (which itself uses static icons, not live values), and avoids needing a live data source for 8 new activities that are default-OFF anyway (nothing live to show).
- **D-12:** Claude designs both the illustration icons and the one-line description copy for every card — user reviews the result during on-device UAT rather than pre-approving mockups/sketches.

### Claude's Discretion
- Exact resolver-priority table format/location (comment block vs. separate doc) for SC5 — no user preference expressed; Claude picks whatever the researcher/planner finds cleanest given `IslandResolver.swift`'s existing comment-based rank convention (ranks are named comments, not raw ints — new v1.10 cases slot in between existing named ranks, not renumbered).
- Exact migration mechanism for default-OFF new activities — reuse the existing `ActivitySettings.migrateLegacyAccentIfNeeded()` pattern (absent `@AppStorage` key ⇒ default applies; presence-check before ever writing) rather than inventing a new versioned-migration system, since no explicit migration write is needed for brand-new keys.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope. (The generic options-slot, D-09, is a forward-looking foundation decision for THIS phase to build, not a deferred capability — it ships now, empty for most cards, filled in by later phases.)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SETTINGS-04 | The Activities-related Settings sections are replaced by one Droppy-style grid of cards — one card per Live Activity (existing + new), each showing a mini live-preview of that activity's pill, its title, a one-line description, and an on/off toggle | Standard Stack (LazyVGrid), Architecture Patterns 1/2 (data-driven card array + fixed 2-column grid), Code Examples (existing pill icons to reuse per D-11's static-illustration-icon decision) |
| SETTINGS-05 | Every new Live Activity introduced this milestone defaults OFF; every already-shipped activity's existing default (mostly ON, Focus Mode OFF) is preserved exactly as-is by the migration — no existing user's persisted toggle state silently flips | Don't Hand-Roll (no migration code needed — @AppStorage absent-key semantics), Runtime State Inventory (exact key/default preservation table), Common Pitfalls 1-2, Validation Architecture (pre-seeded-domain test requirement) |
</phase_requirements>

## Summary

Phase 59 replaces `SettingsView.swift`'s flat `activitiesSection` Form-rows with a categorized, 2-column `LazyVGrid` of activity cards. This is a pure SwiftUI layout problem — no new frameworks, no new packages, no new permissions. The two things that actually carry risk are (1) SwiftUI's `@AppStorage` property wrapper cannot be constructed dynamically from a string key inside a data-driven array — every toggle must stay a statically-declared `@AppStorage` property exactly as today, then get wrapped into a `Binding<Bool>` for the card model at `body`-build time — and (2) the "no silent flip" migration requirement (SC4) is **not** a migration to build: it falls out for free from Swift's own `@AppStorage(key) var x = <default>` semantics (absent key ⇒ default; present key ⇒ real value), *provided* the plan does not touch any of the 7 existing key names or their current default literals. The real engineering task is designing one reusable `ActivityCard` view + a `CardCategory`/`ActivityCardData` model, wiring 8 new default-OFF `@AppStorage` keys for the not-yet-built v1.10 activities, and writing a resolver-priority reference table (documentation only — no new `IslandPresentation`/`ActiveTransient` cases this phase).

**Primary recommendation:** Build one `ActivityCard: View` (icon, title, description, `Binding<Bool>` toggle, optional "Neu" badge, optional options-chevron) in a new top-level file `Islet/ActivityCard.swift`, driven by a plain `[CardCategory: [ActivityCardData]]`-shaped array built inline in `SettingsView.activitiesSection`'s `body`, each `ActivityCardData.isOn` wrapping one of the existing/new individually-declared `@AppStorage` properties — never attempt a generic string-keyed dynamic `@AppStorage`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Card grid layout/rendering | Frontend (SwiftUI View, `SettingsView.swift` + new `ActivityCard.swift`) | — | Pure presentation; no data layer needed beyond `@AppStorage` |
| Per-activity on/off persistence | Frontend (`@AppStorage` in `SettingsView`/new properties) | Storage (`UserDefaults.standard`) | App-owned preference, `@AppStorage` IS the source of truth (existing convention, `ActivitySettings.swift` header) |
| Default-OFF for new activities / preserved-default for existing | Storage (`UserDefaults` absent-key semantics) | Frontend (`@AppStorage` default literal) | No migration code needed — Swift's own property-wrapper default IS the migration mechanism |
| Resolver-priority documentation (SC5) | Frontend/domain (`IslandResolver.swift` doc comment) | — | Colocated with the code future phases will edit; not a runtime capability, pure documentation artifact |
| Options-slot popover (Focus/OSD only, this phase) | Frontend (`SettingsView.swift`, existing `.popover` pattern) | — | Reuses existing per-toggle `@State` + `.popover(isPresented:)` pattern, unchanged mechanism, just relocated into the card |

## Standard Stack

### Core
No new libraries. This phase is 100% native SwiftUI + Foundation, matching the project's existing "no new dependency for a tiny native surface" convention (see `PROJECT.md`'s Out-of-Scope table, e.g. `SimplyCoreAudio` rejected the same way).

| API | Availability | Purpose | Why Standard |
|-----|---------|---------|--------------|
| `LazyVGrid` + `GridItem(.flexible())` | SwiftUI, macOS 11+ (project targets 15.0+) | 2-column fixed grid (D-02) | The one native SwiftUI grid primitive; `GridItem(.flexible())` × 2 gives a fixed 2-column layout with no adaptive-reflow risk, matching D-02's "fixed at 2 columns, not adaptive" |
| `@AppStorage` | SwiftUI, macOS 11+ | Per-activity on/off persistence | Already the codebase's exclusive persistence mechanism for every activity toggle (`ActivitySettings.swift` header comment, `SettingsView.swift` lines 29-64) |
| `.popover(item:)` or `.popover(isPresented:)` | SwiftUI, macOS 11+ | Options-slot affordance (D-08/D-09/D-10) | Already used for Focus/OSD's permission-explanation popovers — same primitive, no new pattern needed |

### Supporting
None.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `LazyVGrid` | `Grid`/`GridRow` (macOS 13+) | `Grid` is row-based and better suited to tables with column alignment across rows; `LazyVGrid` is the standard choice for a card gallery and matches Droppy's reference layout more directly. No reason to deviate. |
| Individually-declared `@AppStorage` properties + data-driven array | A dynamic `AppStorage`-by-string-key wrapper (custom `@propertyWrapper`) | SwiftUI's `@AppStorage` genuinely cannot be constructed with a runtime string inside a `ForEach` data model — writing a custom dynamic wrapper is possible but is unrequested complexity for 15 total toggles (7 existing + 8 new); the existing per-property pattern already works and this phase should extend it, not replace it (Don't Hand-Roll below). |

**Installation:** None — no `npm install`/SPM package additions for this phase.

**Version verification:** N/A (no new external packages).

## Package Legitimacy Audit

**Not applicable.** This phase installs zero external packages — every capability used (`LazyVGrid`, `@AppStorage`, `.popover`) ships in the SwiftUI/Foundation SDK the project already links. No `slopcheck`/registry verification is needed.

## Architecture Patterns

### System Architecture Diagram

```
SettingsView.activitiesSection (body)
        │
        ├─ builds [CardCategory: [ActivityCardData]] inline, one entry per
        │  activity, each .isOn wrapping an EXISTING @AppStorage property's
        │  $binding (chargingEnabled, nowPlayingEnabled, ... ) or a NEW
        │  default-OFF @AppStorage property for the 8 v1.10 activities
        │
        ▼
ScrollView(.vertical)
        │
        ├─ System-HUDs category header + LazyVGrid(columns: 2)
        │     ActivityCard × N  (existing-first, then "Neu"-badged new cards)
        ├─ Medien category header + LazyVGrid(columns: 2)
        │     ActivityCard × N
        └─ Produktivität category header + LazyVGrid(columns: 2)
              ActivityCard × N  (currently ALL new/"Neu", per D-07)

ActivityCard (new file, Islet/ActivityCard.swift)
        │
        ├─ static illustration icon (SF Symbol, pill-colored) — D-11
        ├─ title + one-line description (Claude-authored copy — D-12)
        ├─ Toggle(isOn: Binding<Bool>) — writes straight back into the
        │  @AppStorage property that produced the binding, no indirection
        ├─ optional "Neu" badge (D-04) — driven by ActivityCardData.isNew
        └─ optional options-chevron (D-09/D-10) — tapping calls an
           onOptionsTap: (() -> Void)? closure; Focus/OSD pass their
           EXISTING showFocusPermissionExplanation / showOSDPermissionExplanation
           @State toggles (D-08: same popover, relocated); every other
           card passes nil (chevron hidden)

IslandResolver.swift (doc-comment only, no new cases this phase)
        │
        └─ SC5 resolver-priority reference table — documents current
           4-tier ActiveTransient rank + ambient tiers, plus a "reserved
           slot" note per v1.10 activity for its OWN later phase to fill in
```

### Recommended Project Structure
```
Islet/
├── SettingsView.swift        # activitiesSection rebuilt as grid; existing
│                              # @AppStorage properties stay declared here,
│                              # 8 new ones added alongside them
├── ActivityCard.swift         # NEW — CardCategory enum, ActivityCardData
│                              # struct, ActivityCard view (mirrors the
│                              # top-level flat-file convention: no Views/
│                              # subfolder exists in this codebase today)
├── ActivitySettings.swift     # +8 new key constants (activity.capsLock,
│                              # activity.timer, activity.meetingHUD,
│                              # activity.quickNotes, activity.quickActions,
│                              # activity.menuBarOverflow,
│                              # activity.codingProgress,
│                              # activity.downloadProgress) — key namespace
│                              # only, no new enums/logic needed
└── Notch/
    └── IslandResolver.swift   # + SC5 doc-comment table near the existing
                                # D-02 rank comments; zero functional change
```

### Pattern 1: Static `@AppStorage` properties feeding a data-driven card array
**What:** Every toggle stays a normal, individually-declared `@AppStorage` property (exactly like today's `chargingEnabled`, `nowPlayingEnabled`, etc.). Inside `activitiesSection`'s `body`, build a plain array/dictionary of `ActivityCardData` values, each carrying a `Binding<Bool>` produced from the matching `$property`.
**When to use:** Any time SwiftUI persistence needs to be rendered in a loop/grid — this is the only correct way to combine `@AppStorage`'s static-property requirement with a dynamic `ForEach`.
**Example:**
```swift
// Source: SwiftUI @AppStorage docs (property wrapper, evaluated at compile
// time against a literal key) + this codebase's existing pattern
// (SettingsView.swift lines 29-64)
@AppStorage(ActivitySettings.chargingKey) private var chargingEnabled = true
@AppStorage(ActivitySettings.capsLockKey) private var capsLockEnabled = false  // NEW, v1.10, default OFF

private var systemHUDCards: [ActivityCardData] {
    [
        ActivityCardData(id: "charging", title: "Charging", description: "…",
                          icon: "bolt.fill", isOn: $chargingEnabled, isNew: false, onOptionsTap: nil),
        ActivityCardData(id: "capsLock", title: "Caps Lock", description: "…",
                          icon: "capslock.fill", isOn: $capsLockEnabled, isNew: true, onOptionsTap: nil),
        // … remaining System-HUDs cards, existing-first per D-03
    ]
}
```

### Pattern 2: 2-column fixed `LazyVGrid` per category, inside the existing `ScrollView`
**What:** `activitiesSection` keeps its outer `ScrollView(.vertical)` (already required — the window is fixed 600×380 and the Activities section already overflows it per the current code's comment at `SettingsView.swift:258-261`). Each category is a `Text` header followed by its own `LazyVGrid`.
**When to use:** This phase's grid — D-01 (categorized, not flat) + D-02 (fixed 2 columns).
**Example:**
```swift
// Source: Apple SwiftUI documentation, LazyVGrid — https://developer.apple.com/documentation/swiftui/lazyvgrid
private let twoColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

private var activitiesSection: some View {
    ScrollView(.vertical) {
        VStack(alignment: .leading, spacing: 20) {
            categorySection(title: "System-HUDs", cards: systemHUDCards)
            categorySection(title: "Medien", cards: mediaCards)
            categorySection(title: "Produktivität", cards: productivityCards)

            // D-05: NOT cards — plain toggles in their own non-activity block
            Form {
                Toggle("Launch Islet at login", isOn: $launchAtLogin) /* … */
                Toggle("Automatically Check for Updates", isOn: $autoUpdateCheckEnabled)
            }
        }
        .padding(20)
    }
}

private func categorySection(title: String, cards: [ActivityCardData]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title).font(.headline)
        LazyVGrid(columns: twoColumns, spacing: 12) {
            ForEach(cards) { card in ActivityCard(data: card) }
        }
    }
}
```

### Pattern 3: Options-slot affordance reuses the existing per-toggle popover, relocated
**What:** D-09/D-10 ask for one generic options-chevron per card, but only 2 cards (Focus Mode HUD, OSD-Suppression) actually use it this phase. Do NOT build a shared item-based popover-router for a capability only 2 of 15 cards exercise today — pass `onOptionsTap: (() -> Void)?` on `ActivityCardData`, `nil` for every card except Focus/OSD, which pass a closure that flips their EXISTING `@State` bool (`showFocusPermissionExplanation`, `showOSDPermissionExplanation`). The `.popover(isPresented:)` modifier itself can stay attached exactly where it is today (on the toggle/card), just inside the new card view instead of a `Form` row.
**When to use:** This phase, for Focus/OSD only. A later phase that needs the chevron on a 3rd/4th card can extend the same `onOptionsTap` closure param — no card-component redesign required, which is the entire point of D-09's "generic foundation" framing.

### Anti-Patterns to Avoid
- **Dynamic string-keyed `@AppStorage`:** `@AppStorage(dynamicVariable)` inside a `ForEach` row builder does not work as a live, source-of-truth binding the way a statically-declared property does — SwiftUI's property wrapper needs a literal/constant key at the call site where it's declared as a property, not inside a computed view builder. Keep every toggle a named property.
- **Wrapping the card grid in `Form`/`Section`:** `Form` applies its own list-row chrome (background, insets, separators) that will visually fight a custom card design (rounded rect, icon, badge). Keep the grid in a plain `VStack`/`LazyVGrid`, exactly as Pattern 2 shows — `Form` stays reserved for the non-card "Launch at login"/"Auto-update" toggles per D-05.
- **A generic item-based popover router before it's needed:** Building a shared `activePopoverCard: ActivityCardID?` + single `.popover(item:)` router for a capability only 2 cards use is speculative infrastructure the phase's own CONTEXT.md discretion note doesn't ask for; the plain-closure approach in Pattern 3 is the smaller, equally-extensible diff.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| 2-column card grid | A manual `HStack`-of-`VStack`-pairs layout with index-based chunking | `LazyVGrid(columns: [GridItem(.flexible())×2])` | Native primitive handles wrapping/spacing/alignment for free, no off-by-one chunking bugs |
| Migration-safe default preservation (SC4) | A versioned migration system / explicit "if first launch after v1.10, write defaults" pass | Nothing — Swift's own `@AppStorage(key) var x = <literal>` already returns the literal only when the key is absent | `ActivitySettings.migrateLegacyAccentIfNeeded()` (the CONTEXT.md-cited precedent) was needed because that migration COPIES a value from one key to three new keys. This phase needs no copy at all — every existing key keeps its existing name and existing default; every new key is genuinely new. Writing migration code here would be solving a problem that doesn't exist. |
| Per-card options popover state | A generic keyed-popover dictionary/router | Two named `@State` bools already in `SettingsView.swift` (`showFocusPermissionExplanation`, `showOSDPermissionExplanation`), reused via closure param | See Pattern 3/Anti-Patterns above |

**Key insight:** The single biggest risk in this phase is *building solutions to problems that don't exist* — an explicit migration mechanism (none needed) and a generic dynamic-popover router (only 2/15 cards need it). Both temptations come from over-reading D-09's "generic foundation" language; the correct scope is "the card component accepts an optional closure," not "the card component ships a full options-slot subsystem."

## Runtime State Inventory

Not applicable in the strict rename/refactor/migration sense — no code, key, or file is being renamed. Answered explicitly anyway because SC4 hinges on the same class of question ("what runtime state exists that a naive rewrite could silently disturb"):

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data (`UserDefaults` keys) | 7 existing `ActivitySettings` keys (`activity.charging`, `activity.nowPlaying`, `activity.songChangeToast`, `activity.device`, `activity.calendarCountdown`, `activity.focus`, `activity.osdSuppression`) plus 2 non-activity keys folded into the same Activities Form today (`autoUpdateCheckKey`, and `LaunchAtLogin`'s own system-level state, not UserDefaults) | Code edit only — keep every existing key NAME and DEFAULT LITERAL byte-for-byte identical; only their *presentation* (Form row → card) changes |
| Live service config | None — no external service, no n8n/Datadog-style out-of-git config exists for this feature | None |
| OS-registered state | None — `LaunchAtLogin`'s system registration is untouched, only its Settings-window placement (D-05: stays a plain toggle, not a card) | None |
| Secrets/env vars | None | None |
| Build artifacts | None — no renamed target/package | None |

**The one genuine new-write concern:** 8 new `@AppStorage` keys must be added with `= false` as their literal default (never `= true`), and must NOT reuse or collide with any of the 7 existing key strings. Verify via `grep -n '"activity\.' Islet/ActivitySettings.swift` before/after the plan lands, to confirm exactly 15 distinct `activity.*` keys exist post-phase (7 old + 8 new), none renamed.

## Common Pitfalls

### Pitfall 1: New activity keys accidentally defaulting to `true`
**What goes wrong:** Copy-pasting an existing `@AppStorage(...) var x = true` declaration as a template for a new v1.10 toggle and forgetting to flip the literal to `false` silently violates SC3 (every new activity must default OFF).
**Why it happens:** 5 of the 7 existing toggles default `true`; only `focusKey`/`osdSuppressionKey` default `false`, so the more common existing pattern is the wrong one to copy for new keys.
**How to avoid:** Every one of the 8 new `@AppStorage` declarations must read `= false`, with no exceptions. Add one XCTest per new key asserting `ActivitySettings.<newKey>` maps to a card whose `ActivityCardData.isNew == true` (Wave 0 gap below covers the direct default-value assertion).
**Warning signs:** A code review or test that greps for `@AppStorage(ActivitySettings\.\w+Key)\s*=\s*true` and finds any of the 8 new key names.

### Pitfall 2: Testing the migration claim (SC4) with a fresh install instead of a pre-seeded domain
**What goes wrong:** A fresh `UserDefaults` suite has no existing keys at all, so a test against it can't distinguish "correctly preserved" from "coincidentally defaulted the same way."
**Why it happens:** It's the easier test to write — `ActivitySettingsTests.swift`'s own precedent (`testMigrationOnFreshInstallWritesNothing`) uses a fresh suite for a DIFFERENT assertion (no-write), which could be miscopied for this different claim.
**How to avoid:** SC4's own wording is explicit: "verified against a pre-seeded (upgrade-simulating) UserDefaults domain, not just a fresh install." Write a test that does `defaults.set(false, forKey: ActivitySettings.chargingKey)` (simulating a real user who turned Charging off pre-upgrade) then asserts the grid's binding for that card reads `false`, not the code's `true` default. This is the actual regression SC4 guards against — a naive rewrite that reads the WRONG key, or that accidentally writes an explicit "seed all cards" pass on first launch, would pass a fresh-install test but fail this one.
**Warning signs:** Any test file for this phase that only exercises fresh/empty `UserDefaults` suites.

### Pitfall 3: LazyVGrid inside ScrollView inside the fixed 600×380 window overflowing without visible scroll affordance
**What goes wrong:** 15 cards across 3 categories (System-HUDs 5, Medien 2, Produktivität up to 4 today/8 eventually) at 2-per-row is 7-8 rows — comfortably taller than the 380pt window height budget once category headers, padding, and the non-card Form block are added. If the outer `ScrollView` is dropped or mis-scoped, the bottom cards/rows become unreachable exactly like the pre-Phase-51 bug this codebase already hit once (`SettingsView.swift:258-261`'s own comment references the prior overflow fix).
**Why it happens:** It's easy to reuse Pattern 2's `ScrollView` wrapper for the grid but forget the "Launch at login"/"Auto-update" `Form` block also needs to live INSIDE that same scroll region (D-05 keeps them in the Activities detail view, just not as cards).
**How to avoid:** Keep exactly one `ScrollView(.vertical)` wrapping the entire `activitiesSection` body (grid + the plain-toggle block), mirroring the current file's existing single-`ScrollView`-per-section convention used by every other sidebar section (`appearanceSection`, `fullscreenSection`, etc.).
**Warning signs:** On-device UAT where scrolling the Activities pane doesn't reach "Automatically Check for Updates" or the last Produktivität card.

### Pitfall 4: Icon/copy design becomes a hidden scope-creep magnet
**What goes wrong:** D-12 hands Claude full discretion over 15 illustration icons + 15 one-line descriptions with no user pre-approval — it's tempting to treat this as a chance to also redesign wording/tone across the whole Settings window, which is out of this phase's boundary (only the Activities grid + non-activity toggle block + resolver table).
**Why it happens:** Once inside `SettingsView.swift` making copy decisions, adjacent sections (Appearance, Fullscreen, etc.) are right there and look inconsistent by comparison.
**How to avoid:** Icons/copy are scoped to the 15 (7 existing + 8 new) Activities cards only; reuse each activity's EXISTING pill icon where one already exists in `NotchPillView.swift` (see Code Examples below) rather than inventing new symbols for shipped activities — keeps the card's icon visually traceable to the real pill the user already recognizes.
**Warning signs:** A diff touching `appearanceSection`/`fullscreenSection`/`weatherSection` copy or icons.

## Code Examples

### Existing pill icons to reuse for card illustrations (traceability, D-11)
```swift
// Source: Islet/Notch/NotchPillView.swift, grepped systemName: usages
// Charging wing:              "bolt.fill"                    (line 2379)
// Now Playing (play state):   "play.fill" / "pause.fill"     (line 3002)
// Focus Mode HUD:              "moon.fill"                    (line 2600)
// Calendar Countdown:          "calendar"                     (line 2648)
// OSD — volume (muted/not):    "speaker.slash.fill" / "speaker.wave.3.fill" (line 2731)
// OSD — brightness:            "sun.max.fill"                 (line 2735)
// Device: dynamic via deviceSymbol(for:) — no single constant; card should
//   use a neutral device glyph (e.g. "antenna.radiowaves.left.and.right",
//   already used for the Bluetooth permission row in permissionsSection)
//   since the real pill icon varies per connected device type.
// Song-Change Toast: no dedicated pill icon exists (it's a text-only toast,
//   not an icon+label wing) — needs a new illustration icon, e.g. "text.bubble.fill".
```

### `LazyVGrid` fixed 2-column reference
```swift
// Source: Apple Developer Documentation — LazyVGrid
// https://developer.apple.com/documentation/swiftui/lazyvgrid
LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
    ForEach(cards) { card in
        ActivityCard(data: card)
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| Flat `Form { Section("Activities") { Toggle(...) } }` list of 7 toggles + 1 permission popover pair | Categorized 2-column `LazyVGrid` of illustrated cards | This phase (Phase 59) | Larger visual footprint per activity (icon + description vs. one line), requires the `ScrollView` overflow handling already proven necessary in Phase 51 |

**Deprecated/outdated:** The old `Toggle("Charging", isOn: $chargingEnabled)` inline-in-Form row pattern for activity toggles is replaced by card rendering; the underlying `@AppStorage` properties and keys are NOT deprecated — they are the persistence layer both old and new UI read/write identically.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The 8 new v1.10 `@AppStorage` key names (`activity.capsLock`, `activity.timer`, `activity.meetingHUD`, `activity.quickNotes`, `activity.quickActions`, `activity.menuBarOverflow`, `activity.codingProgress`, `activity.downloadProgress`) — exact strings are this researcher's proposal, not yet confirmed against any later phase's own RESEARCH.md | Standard Stack / Project Structure | Low — these are internal, never user-facing; a later phase (60-67) could rename its own key with no cross-phase breakage since no other code reads them until that phase builds the real activity. Flag for planner: lock the exact 8 strings once, here, so Phase 60-67 don't each invent their own naming convention. |
| A2 | Illustration-icon mapping for Song-Change Toast (no existing pill icon) and Device (dynamic icon, no single constant) — proposed icons (`text.bubble.fill`, `antenna.radiowaves.left.and.right`) are this researcher's suggestion, not user-confirmed | Common Pitfalls #4 / Code Examples | Low — D-12 explicitly delegates icon/copy design to Claude with on-device UAT review, so any reasonable choice is correctable in that UAT loop, not a locked decision |
| A3 | Resolver-priority table (SC5) is best placed as a doc-comment inside `IslandResolver.swift` rather than a separate `.planning/` markdown file — CONTEXT.md explicitly leaves this to researcher/planner discretion; this is a recommendation, not a verified requirement | Architecture Patterns (diagram) | Low — either location satisfies "a reviewed resolver-priority table exists"; a separate file is an equally valid planner choice if the plan-checker or user prefers docs decoupled from source |

## Open Questions

1. **Exact resolver-tier assignment for each of the 8 new v1.10 activities**
   - What we know: `IslandResolver.swift`'s current tiers are (0) onboarding forced-flow, (1) `ActiveTransient` queue ranked charging > device > focus (collapsed-only) > osd (collapsed-only), (2) `isExpanded` branch (pendingDrop > selectedView calendar/weather/tray > nowPlaying > home fallback), (3) non-expanded ambient (calendarCountdown always-wins > launch-gated nowPlayingWings > idle). ROADMAP.md's phase descriptions give strong hints: Caps Lock = "same transient wings pattern as Charging" (transient tier); Timer/Meeting-HUD = persistent-transient (Phase 62 "generalizes `TransientQueue.preempt()`/`isPersistent` beyond Focus Mode," Phase 63 explicitly depends on that generalization); Coding-Progress = likely ambient tier like Calendar Countdown (Phase 67 "reuses Phase 61's FileWatcher pattern," Download-Progress is presence+completion, closer to a short-lived transient); Quick Notes and Menübar-Overflow appear to need NO `IslandPresentation` case at all (menu-bar-only UI, never touch the pill); Quick Actions bar's exact resolver relationship is unclear from the roadmap text alone (could be an always-visible strip, not a presentation case).
   - What's unclear: Exact numeric rank for Caps Lock/Timer/Meeting-HUD/Download-Progress/Coding-Progress relative to each other and to the 4 existing transients — the ROADMAP only fixes BUILD ORDER (59→60→61→62→63→64→65→66→67), not resolver RANK order, and these need not match.
   - Recommendation: SC5 only requires "a reviewed resolver-priority table exists... so later phases slot in without silently reordering existing precedence" — Phase 59's table should document the CURRENT 4 tiers precisely (verified against the code above) and list each of the 8 new activities with its best-guess tier + an explicit "rank TBD, confirm in that activity's own phase discussion" flag, rather than pre-deciding numeric ranks this phase has no mandate to lock.

2. **Does Quick Actions bar (Phase 65) get a grid card in Produktivität at all, given it's a persistent bar not a toggleable "activity" in the Charging/Focus sense?**
   - What we know: D-07 assigns "Produktivität = reserved for new v1.10 activities (Timer/Pomodoro, Meeting-HUD, Quick Notes, Quick Actions bar)" — CONTEXT.md explicitly lists it as a card.
   - What's unclear: Whether its card's toggle enables/disables the whole bar (binary on/off, matching "one card per toggle" D-06 precedent) or whether its later phase needs a richer "enable + reorder" UI that doesn't fit the plain-toggle card shape.
   - Recommendation: This phase only needs the on/off toggle (matching QACTION-01's "Settings lets the user enable/reorder" — enable is this phase's card, reorder is Phase 65's own separate UI). No blocker for Phase 59 planning.

## Environment Availability

Skipped — this phase has no external tool/service/runtime dependencies beyond the Xcode toolchain the project already builds with (no new SPM packages, no new permissions, no new system frameworks).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest, `IsletTests` target (`@testable import Islet`) |
| Config file | `Islet.xcodeproj` / `project.yml` (xcodegen-managed), no separate test config |
| Quick run command | `xcodebuild -project Islet.xcodeproj -scheme Islet build` (build-only — **do not** run `xcodebuild test` headlessly; it hangs in this repo due to a Bluetooth TCC-authorization wait in `BluetoothMonitor`, documented in `PROJECT.md` line 425 and reconfirmed at Phase 56/58) |
| Full suite command | Manual Cmd-U in Xcode (interactive session required) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SETTINGS-04 | Grid renders one card per activity, grouped by category (D-01/D-02/D-03/D-07) | unit (pure data-model assertions on the card array, not full SwiftUI render) | `xcodebuild build` (compiles) + manual Cmd-U/`ActivitySettingsTests`-style assertions on `systemHUDCards`/`mediaCards`/`productivityCards` counts and ordering | ❌ Wave 0 — needs new test target additions in `ActivitySettingsTests.swift` or a new `ActivityCardTests.swift` |
| SETTINGS-04 | Toggling a card enables/disables the activity exactly like today (SC2) | manual-only (on-device UAT — no headless mechanism observes actual `IslandPresentation` behavior change) | N/A — checklist item in the phase's UAT plan | — |
| SETTINGS-05 | Every new v1.10 activity key defaults `false` (SC3) | unit | `ActivitySettingsTests.swift`-style: `XCTAssertEqual(defaults.bool(forKey: ActivitySettings.capsLockKey), false)` per new key, mirroring existing `testFocusKeyName`-style key-name assertions | ❌ Wave 0 |
| SETTINGS-05 | Existing activity toggle state preserved exactly across upgrade, tested against a pre-seeded (not fresh) `UserDefaults` domain (SC4) | unit | New test: seed `UserDefaults(suiteName:)` with a non-default value for an existing key (e.g. `chargingKey = false`), assert the card-array binding reads that seeded value, not the code's compiled-in default | ❌ Wave 0 |
| SETTINGS-04/05 | Resolver-priority table exists and matches the CURRENT code (SC5) | manual-only (a documentation-review checkpoint, not a runtime test) | N/A — plan-checker/human review of the doc-comment/table against `IslandResolver.swift`'s real `resolve()`/`TransientQueue` logic | — |

### Sampling Rate
- **Per task commit:** `xcodebuild -project Islet.xcodeproj -scheme Islet build` (build-only, matches the repo-wide headless-test-hang workaround)
- **Per wave merge:** Manual Cmd-U in Xcode for the full `IsletTests` suite (existing `ActivitySettingsTests`, new card/migration tests, `IslandResolverTests` regression)
- **Phase gate:** On-device UAT (SC2 toggle-behavior, SC3 fresh-install default-OFF check, SC4 pre-seeded-domain upgrade-simulation check) before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `IsletTests/ActivitySettingsTests.swift` — add default-value assertions for the 8 new keys (covers SETTINGS-05 SC3)
- [ ] A new or extended test — pre-seeded `UserDefaults(suiteName:)` domain asserting existing-key values survive unchanged through the new card-array binding path (covers SETTINGS-05 SC4; this is the one genuinely new test shape this phase needs, no existing precedent covers "read a seeded non-default value through a Binding built from @AppStorage")
- [ ] No new test framework/config needed — `IsletTests` target and XCTest already fully cover this phase's testing needs

## Security Domain

`security_enforcement` is absent from `.planning/config.json` (defaults to enabled), but this phase has no attack surface worth an ASVS table: it adds zero new network calls, zero new permission grants, zero new external input parsing, and zero new persisted data beyond boolean `UserDefaults` flags the app already reads/writes exclusively locally. No ASVS category meaningfully applies.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | N/A — no auth surface |
| V3 Session Management | No | N/A |
| V4 Access Control | No | N/A |
| V5 Input Validation | No | No user-typed input in this phase (toggles only, not text fields) |
| V6 Cryptography | No | N/A — `UserDefaults` booleans, same trust level as the 7 existing activity flags already stored unencrypted |

### Known Threat Patterns for this stack
None applicable — a local, unauthenticated, single-user macOS settings toggle grid has no meaningful STRIDE surface beyond what the existing 7 toggles already carry (none).

## Sources

### Primary (HIGH confidence)
- `Islet/SettingsView.swift` (full file read) — existing `activitiesSection`, `@AppStorage` property declarations, `ScrollView` overflow precedent, popover pattern
- `Islet/ActivitySettings.swift` (full file read) — key namespace convention, `migrateLegacyAccentIfNeeded()` precedent cited by CONTEXT.md
- `Islet/Notch/IslandResolver.swift` (full file read) — `IslandPresentation`/`ActiveTransient` enums, `resolve()` tier logic, `TransientQueue` rank-comment convention
- `IsletTests/ActivitySettingsTests.swift`, `IsletTests/SettingsViewTests.swift` (full file read) — existing test shape/conventions for this file's testing needs
- `.planning/phases/59-settings-redesign/59-CONTEXT.md` — locked decisions D-01 through D-12, canonical refs
- `.planning/REQUIREMENTS.md` — SETTINGS-04, SETTINGS-05 exact wording
- `.planning/ROADMAP.md` — Phase 59-67 goal/success-criteria text (used for Open Question 1's resolver-tier hints)
- `.planning/STATE.md` — Phase 56/58 notes on `xcodebuild test` headless hang, confirming `PROJECT.md`'s documented workaround
- `.planning/PROJECT.md` line 425 — canonical statement of the `xcodebuild test` hang + `xcodebuild build`/manual-Cmd-U workaround
- `.planning/research/inspiration/notes.md` line 43 — Droppy's own HUD-grid reference (static icons, not live preview, confirming D-11's rationale)
- Apple Developer Documentation, `LazyVGrid` (`developer.apple.com/documentation/swiftui/lazyvgrid`) — grid API shape (training-data knowledge of a long-stable, unchanged SwiftUI API; not independently re-fetched this session, but the API surface used here — `GridItem(.flexible())`, `spacing:` — has been stable since introduction and matches this codebase's own macOS 15.0+ deployment target)

### Secondary (MEDIUM confidence)
None — all findings above are either directly grepped/read from this codebase or the phase's own planning documents.

### Tertiary (LOW confidence)
None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero new dependencies, pure existing-SDK usage confirmed against this codebase's own current SwiftUI/macOS-15.0 deployment target
- Architecture: HIGH — every pattern is either a direct extension of code already read in full (`SettingsView.swift`, `ActivitySettings.swift`) or Apple's own stable `LazyVGrid` API
- Pitfalls: HIGH — Pitfalls 1-3 are derived directly from this codebase's own prior incidents (Phase 51's Form-overflow fix, `ActivitySettingsTests`' own migration-test precedent) and D-locked requirements' literal wording (SC3/SC4), not speculative

**Research date:** 2026-07-23
**Valid until:** No expiry risk — this is a self-contained SwiftUI/Foundation-only phase with no external API surface to go stale; safe for the planner to treat as current indefinitely within this milestone.
