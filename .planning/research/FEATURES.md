# Feature Research

**Domain:** macOS menu-bar/notch utility app — v1.4 feature scope (onboarding, Settings sidebar, visual/material redesign, calendar view)
**Researched:** 2026-07-11
**Confidence:** MEDIUM-HIGH (SwiftUI/AppKit APIs verified against official docs; UX pattern claims verified against multiple sources; two project-specific gotchas flagged LOW/MEDIUM pending on-device verification)

This research supersedes the previous (v1.3 shelf-focused) FEATURES.md — it answers "how do polished macOS utilities implement this well" for the 4 new feature areas scoped in `.planning/PROJECT.md`'s v1.4 goals, cross-referenced against `.planning/research/inspiration/notes.md` (Droppy screenshots). It does not re-litigate whether to build these — only how.

## Feature Landscape

### Area 1 — First-Launch Onboarding (trial/license choice + permission pre-explanation)

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Multi-step carousel (3-4 screens: hero → license choice → permissions → done) | Droppy `1.png`-`4.png`; standard pattern for any paid utility's first run | LOW | SwiftUI `TabView(selection:)` with `.tabViewStyle(.page)` or a hand-rolled `@State` step index + `matchedGeometryEffect`/transition — Islet already has spring/geometry infra to reuse |
| Trial/license-key/buy choice as an onboarding STEP, not a passive Settings row | Explicit v1.4 goal; today it's passive in Settings | LOW | Pure UI work — wraps the already-shipped `TrialService`/`LicenseService`/`PolarLicenseService` from Phase 10-12, zero new business logic |
| Skippable/dismissible flow, shown once (persisted flag) | Standard first-run UX; a non-dismissible modal reads as hostile in a $7.99 utility | LOW | One new `@AppStorage("hasCompletedOnboarding")` bool, distinct from the existing trial-start flag |
| Permission pre-explanation screen: one line of "why" per permission, shown BEFORE the system TCC dialog fires | Droppy `2.png`; user explicitly called this out as liked; general macOS best practice — a custom pre-prompt doesn't burn the one shot at the real system dialog if declined | MEDIUM | Real macOS pattern, verified via WebSearch (MEDIUM confidence, general best-practice consensus, not Apple-official). See Dependencies below — this is the one item with a hard project-specific ordering constraint |

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Permission requests sequenced to match Islet's actual startup dependency order (Bluetooth → Calendar → Location/WeatherKit) rather than firing in file/alphabetical order | Avoids a jarring double-prompt UX where the system dialog for Bluetooth appears mid-onboarding for a feature the user hasn't even seen yet | LOW-MEDIUM | Ties directly to the project's own known crash history (Bluetooth register needs the Info.plist key present — already fixed in Phase 6-04; the *new* work is making the onboarding screen the deliberate trigger point instead of a lazy background monitor start) |
| "Replay this intro" entry point (About section) | Droppy `30.png`-`31.png`; cheap, high-trust, lets a confused user re-see the flow without reinstalling | LOW | Just re-presents the same onboarding view; no new state beyond a manual trigger |

#### Anti-Features

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|------------------|-------------|
| In-app gesture/feature tutorial screen | Droppy `3.png` does this and it "feels complete" | User explicitly rejected it; also touches the same event-delivery layer the project just deferred (gesture nav is out of scope for v1.4 entirely) | Skip it — go hero → license choice → permissions → done |
| Requesting all TCC permissions back-to-back with no explanation | Feels efficient — "get it over with" | Lower grant rates; users decline blind system dialogs at a measurably higher rate than pre-explained ones (28% higher grant rate cited for contextual/deferred asks per UX research, MEDIUM confidence single-source) | One pre-explain screen per permission, or a single screen listing all with per-line reasons, but never a silent chain of system dialogs |
| A full onboarding "product tour" walking every Settings option | Feels thorough | Onboarding fatigue — directly the same objection the user had to the gesture tutorial, generalized | Keep onboarding to identity (trial/license) + trust (permissions) only; Settings discovery happens organically |

**Dependencies (project-specific, from downstream-consumer brief):**
- The Bluetooth permission pre-explainer must exist and be shown **before** `BluetoothMonitor`'s first `IOBluetoothDevice.register(forConnectNotifications:)` call, because the project's own memory confirms `NSBluetoothAlwaysUsageDescription` absence is a **hard crash**, not just a missing prompt (already fixed by adding the Info.plist key in Phase 06-04). The onboarding redesign's job is UX sequencing (explain-then-trigger), not re-fixing the crash — but the pre-explain screen's "Continue" action should be the thing that (re)triggers `BluetoothMonitor` start, so the explanation always precedes the OS prompt in wall-clock time even on a fresh install where the coordinator might otherwise start eagerly at launch.
- Calendar's quick-add capability (Area 4) needs a **broader** EventKit authorization tier than the existing read-only glance — see Area 4 Dependencies. The onboarding permission screen's calendar copy should describe both read (glance) and write (quick-add) up front rather than surprising the user with a second calendar prompt later.
- WeatherKit doesn't have its own TCC prompt (it rides on the Location permission) — one pre-explanation line covering "Location — powers the weather glance" covers both.

---

### Area 2 — Visual/Material Redesign (frosted pill, slower springs)

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Non-fully-transparent "frosted/glossy" fill replacing the current black fill | Explicit user requirement — full transparency "feels wrong" even though it "shines more" | MEDIUM | SwiftUI `Material` (`.regularMaterial`/`.thickMaterial`) layered under a subtle dark tint + hairline highlight border, NOT `NSVisualEffectView` — see Anti-Features, this is a project-specific pitfall |
| One shared material/shape token across collapsed pill, expanded pill, and activity wings | Visual consistency; today's fills are likely per-view ad hoc opacity values | LOW-MEDIUM | Pure refactor — extract a `NotchMaterialStyle` (or similar) SwiftUI `ViewModifier`/shape style used everywhere the blob renders |
| Legible content over any desktop wallpaper (contrast/a11y baseline) | Any real material effect that goes translucent risks unreadable white-on-white or black-on-black text | LOW | Verify on-device against light and dark wallpapers; add a minimum-contrast fallback tint if needed |

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Animation Speed presets (Droppy's Turtle/Human/Cheetah/Falcon) exposed as a Settings slider/segmented control | Directly reusable idea — Islet's spring already lives in one place (`matchedGeometryEffect` + `.spring(response:dampingFraction:)`), presets just parameterize `response` | LOW-MEDIUM | 4 named presets mapping to different `response` values (e.g. 0.5/0.35/0.25/0.15s), same `dampingFraction`; store as `@AppStorage` |
| Slower/more deliberate default spring than today ("360Hz monitor" feel — smooth even when slow) | Matches explicit user feedback; a well-tuned SwiftUI spring achieves "premium slow" without dropping frames, unlike a hand-timed linear animation | LOW | Tuning exercise, not new API — raise `response`, keep `dampingFraction` high enough to avoid visible bounce/overshoot |
| Theming section (surface style: Dynamic Glass vs. flat Black; per-element color pickers with a "Default" auto option) | Droppy `27.png`-`29.png`; extends the already-shipped accent-color picker into a proper Theming settings section | LOW-MEDIUM | Incremental extension of existing `@AppStorage` accent-color code — not new infrastructure |

#### Anti-Features

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|------------------|-------------|
| Apple's new `.glassEffect()` / "Liquid Glass" material API as the *only* implementation | It's the newest, most "native-2026" glass look and the build machine already runs Tahoe/Xcode 26 | **`.glassEffect(_:in:)` requires macOS 26.0+** (HIGH confidence, Apple docs). Islet's deployment floor is macOS 14.0 (Key Decision in PROJECT.md) — making Liquid Glass mandatory would silently cut off every user still on Sonoma/Sequoia, which is most of the notch-Mac install base in 2026 | Build the frosted look with SwiftUI `Material` (works back to macOS 12), and *optionally* layer `.glassEffect()` behind `if #available(macOS 26, *)` as a progressive enhancement, never as the base path |
| `NSVisualEffectView`-backed real vibrancy blur on the notch panel | It's the "correct" AppKit vibrancy primitive and is what system chrome uses | `NSVisualEffectView` is a real system compositor layer that samples desktop content behind the window — layering it into an always-on-top, click-through, all-Spaces, non-activating `NSPanel` risks the exact class of hit-testing/compositing regression the project already fought once (Phase 20's CR-01 empty-shelf click-swallowing bug, caused by an invisible band silently intercepting clicks). SwiftUI `Material` renders as a normal content layer inside the existing SwiftUI view tree and doesn't add a second compositing surface | SwiftUI `Material` modifiers only; if true vibrancy is desired later, spike it in isolation with an explicit click-through regression test before adopting |
| Fully transparent glass | Droppy leans this way and it does "shine more" per the user's own observation | User explicitly rejected it for Islet | Frosted `Material` with tint, not `Color.clear`/pure blur |

**Dependencies:**
- This area intersects the *separate* NotchPanel/NotchWindowController architecture redesign research track — whether the panel is opaque, layer-backed, etc. affects whether `Material` composites correctly inside a borderless `NSPanel`. Sequence or coordinate this with that track rather than deciding material strategy in isolation.
- No new permissions, no new frameworks — purely SwiftUI-layer work reusing existing spring/geometry scaffolding.

---

### Area 3 — Settings Sidebar Redesign

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| `NavigationSplitView(sidebar:detail:)` two-column layout replacing the single tabbed `Form` | This is the modern, native macOS System-Settings-style pattern (macOS 13+, well within Islet's 14.0 floor); it's what Droppy's own sidebar visually resembles | LOW-MEDIUM | Mostly a restructuring of existing tab content into per-section detail views — no new data model. Islet's Settings already lives in a plain `Window(id:)` (per project memory: the SwiftUI `Settings{}` scene is unreliable on this Tahoe build machine), which is actually simpler to host `NavigationSplitView` in than the `Settings{}` scene would have been — no scene-specific sizing quirks to fight |
| Sidebar sections trimmed to what Islet actually has: **General, Workspace (Shelf), System (Theming/Accessibility), About/License** | Droppy's own taxonomy (`.planning/research/inspiration/notes.md`) is the direct reference, but Droppy has ~10 sections (Shelf/Basket/Clipboard/Lock Screen/Cloud/HUDs/Theming/Accessibility/License/About) built on a plugin ecosystem Islet doesn't have | LOW | Only surface sections for shipped or near-term features; an empty/placeholder section (e.g. "HUDs" before HUD replacement is scoped) invites confusion — omit rather than stub |
| Selected sidebar section persisted across Settings window opens | Small but expected polish; System Settings itself does this | LOW | One `@AppStorage("settingsSelectedSection")` value driving `NavigationSplitView`'s selection binding — verified via WebSearch (MEDIUM confidence, common pattern, not Apple-official doc) |

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| "Permissions Overview — X of Y granted" rollup row in General | Droppy `8.png`; gives the user one glance at trust/permission state without hunting through each feature's toggle | LOW | Reads the same authorization-status values the pre-explainer (Area 1) and each monitor already expose; no new permission-tracking code |
| "Replay onboarding" button in About | Droppy `30.png`-`31.png`; cheap once Area 1's onboarding view exists | LOW | Direct reuse of Area 1's carousel view |

#### Anti-Features

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|------------------|-------------|
| Full plugin-marketplace "Droplets" grid section | Visually the most eye-catching part of Droppy's Settings | Islet has no plugin architecture and building one is explicitly out of scope for this milestone (per PROJECT.md's Droppy-inspiration framing: "raw reference material... not a build list") | Mine individual widget *ideas* later (e.g. calendar-progress-ring) directly into Islet's own feature code, never build a marketplace/loading system |
| Sections for out-of-scope Droppy features (Clipboard, Basket, Lock Screen, Cloud) | Completeness — "why not mirror the whole taxonomy" | Dead UI for features that don't exist reads as broken/unfinished, and clipboard managers/cloud sync were explicitly discussed and ruled out for this milestone | Only 4 sections: General, Workspace, System, About/License |
| Hand-rolled sidebar (`HSplitView` + manual `List` + manual detail-view switching) instead of `NavigationSplitView` | More "control" over exact look | Reinvents a solved platform primitive for a small Settings window at this app's scale — extra code, extra bugs, no visual upside `NavigationSplitView` + styling doesn't already give | `NavigationSplitView`, `.toolbar(removing: .sidebarToggle)` and `.constant(.all)` columnVisibility if the sidebar should never collapse (small fixed-size Settings window) |

**Dependencies:**
- Pure UI reorganization of existing Settings content (General/Appearance/Activities tabs → sidebar sections) — no new data model, no new permissions.
- The "System" section is the natural future home for HUD-replacement settings (long-deferred backlog item) and the Area 2 Theming controls — build the section now for what v1.4 actually ships (Theming, Accessibility-style toggles if any), leave room to extend rather than pre-building empty HUD UI.

---

### Area 4 — Calendar Full View (month grid + day list + quick-add)

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Month grid + selected-day event list | Droppy `6.png`; standard lightweight calendar-glance-app pattern (this is not trying to be Calendar.app) | MEDIUM | Backed by the already-integrated `EKEventStore`/EventKit service from Phase 14 (`CAL-01`) — the grid itself is pure SwiftUI date math (`Calendar`/`DateComponents`), no new framework |
| Empty state ("No upcoming events") | Droppy `7.png`; cheap, expected polish, avoids a dead-looking blank grid | LOW | — |
| Reuses the existing Home/Tray switcher, adding Calendar as the 3rd slot (per PROJECT.md's explicit choice to NOT use Droppy's quick-launch-apps 3rd slot) | Already decided in PROJECT.md's Next Milestone Goals — not open for re-litigation | LOW | View-switcher plumbing work, not calendar-specific |

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Lightweight "add task" quick-entry (Droppy's "New Task" popover: `7.png`) | Matches the "lightweight" framing explicitly requested — a lookup/entry field, not a full editor | MEDIUM | **Important finding:** Apple's built-in `EKEventEditViewController` (from `EventKitUI`) is an iOS/Mac Catalyst-only view controller — it has no macOS/AppKit counterpart (MEDIUM confidence: WebSearch-corroborated across multiple sources, no macOS example found anywhere; Apple's own EventKitUI docs page shows no macOS availability). This means the quick-add form must be hand-built in SwiftUI, calling `EKEventStore.save(_:span:commit:)` directly. This is not a setback — a hand-built minimal form (title + date/time + calendar picker) is *exactly* the "lightweight" scope already wanted, so the constraint and the intended design coincide |

#### Anti-Features

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|------------------|-------------|
| Full calendar CRUD (edit/delete/recurring events, multi-account calendar management) | "Since we're building calendar UI, why not go all the way" | Droppy's own calendar view is add-only/lightweight — a full editor duplicates Apple Calendar.app with no differentiation and meaningfully more EventKit surface area (recurrence rules, alarms, attendees) | Quick-add only (title/date/calendar); let the user tap through to Calendar.app for anything more complex |
| Reimplementing month-grid date math separately for the Home glance's "next event" and the new full Calendar view | Feels like two independent, simpler pieces of code | Duplicates EventKit-service and date-range logic that should be shared; risk of the two views disagreeing on "today" at midnight boundaries, timezone edge cases | One shared calendar/EventKit service layer (extends Phase 14's existing service) consumed by both the Home glance and the new full view |

**Dependencies:**
- **Broader permission tier needed.** The existing Home-glance calendar feature (Phase 14, `CAL-01`) only *reads* events. Since macOS 14+/iOS 17+, EventKit split calendar authorization into full-access vs. write-only tiers (`EKAuthorizationStatus` gained `.writeOnly` alongside `.fullAccess`); writing a new event via `EKEventStore.save()` requires the full-access tier and the corresponding `NSCalendarsFullAccessUsageDescription` Info.plist key. **Verify during planning** whether Islet's existing Info.plist/authorization call already requested full access (likely, since the glance already shows *third-party* event details) or only a narrower read scope — if narrower, this is a new permission surface that also needs its own onboarding pre-explanation line (Area 1) distinguishing "see your events" from "add events on your behalf." (LOW-MEDIUM confidence — flagged for phase-specific verification against the actual Phase 14 code, not just this research.)
- Reuses Phase 14's EventKit service seam — extend, don't duplicate.

---

## Feature Dependencies

```
Area 1: Onboarding
    └──requires──> existing TrialService/LicenseService/PolarLicenseService (Phase 10-12, already shipped)
    └──requires──> per-permission authorization-status reads (Bluetooth/Calendar/Location) already exposed by each monitor
    └──gates──> BluetoothMonitor's first register call (ordering: pre-explain screen must run first)
    └──enhances──> Area 3's About section ("Replay onboarding" reuses this view)

Area 2: Visual/Material Redesign
    └──requires──> existing matchedGeometryEffect + spring animation scaffolding (Phase 2, already shipped)
    └──coordinates-with──> the separate NotchPanel/NotchWindowController architecture redesign (compositing/opacity behavior)
    └──enhances──> Area 3's Theming section (extends the existing accent-color picker)

Area 3: Settings Sidebar
    └──requires──> existing Settings window (already a plain Window(id:), not the Settings{} scene)
    └──requires──> NavigationSplitView (macOS 13+, no deployment-target impact)
    └──hosts──> Area 2's Theming controls and Area 1's "Permissions Overview"/"Replay onboarding"

Area 4: Calendar Full View
    └──requires──> existing EventKit service seam (Phase 14, CAL-01)
    └──requires──> broader (full-access, not read-only) EventKit authorization tier for quick-add
    └──enhances──> existing Home-glance "next event" (should share, not duplicate, the EventKit service layer)
    └──conflicts-with──> EventKitUI's EKEventEditViewController (macOS-unavailable) — must hand-build the quick-add form instead
```

### Dependency Notes

- **Area 1 gates Area 4's permission surface:** if Area 4's quick-add needs a broader Calendar authorization tier than today's glance, Area 1's permission pre-explanation copy for Calendar needs to describe both read and write use cases up front, in one prompt, rather than surprising the user with a second Calendar system dialog when they first use quick-add.
- **Area 2 coordinates with (does not depend on) the architecture redesign:** material/compositing choices should be validated against whatever the new `NotchPanel` shape turns out to be, but Area 2's SwiftUI-layer work itself has no hard blocking dependency on that redesign landing first.
- **Area 3 hosts, but doesn't require, Areas 1 and 2:** the sidebar restructuring can ship independently; it becomes more valuable once Theming (Area 2) and Permissions Overview/Replay onboarding (Area 1) exist to put inside it.

## MVP Definition

### Launch With (v1.4)

- [ ] Onboarding carousel: hero → trial/license/buy choice → permission pre-explanation (Bluetooth, Calendar, Location/WeatherKit) → done — replaces today's passive Settings-only license flow
- [ ] Frosted/glossy `Material`-based pill fill (collapsed + expanded + wings), replacing the current opaque/transparent fill, with a moderately slower default spring
- [ ] `NavigationSplitView` Settings with 4 sections: General, Workspace (Shelf), System (Theming), About/License
- [ ] Calendar full view: month grid + day event list + quick-add form, as the 3rd view-switcher slot

### Add After Validation (v1.x)

- [ ] Animation Speed presets (Turtle/Human/Cheetah/Falcon-style) — once the new default spring feel is validated on-device, expose it as a user-tunable setting
- [ ] "Permissions Overview — X of Y granted" rollup row and "Replay onboarding" button — cheap additions once Areas 1 and 3 both exist
- [ ] Theming surface-style picker (Dynamic Glass vs. flat Black) and per-element color pickers — once the base Material redesign is validated

### Future Consideration (v2+)

- [ ] `.glassEffect()`/Liquid Glass progressive enhancement gated behind `#available(macOS 26, *)` — defer until the macOS 14/15 user base is small enough to accept a two-tier visual experience, or until deployment floor is reconsidered
- [ ] System HUD replacement grid (Volume/Brightness/Caps Lock/etc., Droppy-style) — long-deferred backlog item; Area 3's "System" sidebar section is the natural future home, not built this milestone
- [ ] Individual "droplet"-style mini-widgets (calendar-progress-ring, Pomodoro) mined from Droppy's plugin grid — build directly into Islet's own feature set, never as a plugin system

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Onboarding carousel (trial/license + permission pre-explain) | HIGH | MEDIUM | P1 |
| Frosted/glossy Material pill redesign | HIGH | MEDIUM | P1 |
| Slower/tuned default spring | MEDIUM | LOW | P1 |
| Settings NavigationSplitView sidebar (4 sections) | MEDIUM | MEDIUM | P1 |
| Calendar full view (month grid + day list) | HIGH | MEDIUM | P1 |
| Calendar quick-add (hand-built form) | MEDIUM | MEDIUM | P1 |
| Animation Speed presets | LOW-MEDIUM | LOW-MEDIUM | P2 |
| Permissions Overview rollup row | LOW-MEDIUM | LOW | P2 |
| Replay-onboarding button | LOW | LOW | P2 |
| Theming surface-style/color pickers | LOW-MEDIUM | MEDIUM | P2 |
| `.glassEffect()` Liquid Glass enhancement | LOW | MEDIUM (raises min-OS question) | P3 |
| System HUD replacement grid | HIGH (future) | HIGH | P3 (separate milestone) |

**Priority key:**
- P1: Must have for v1.4 launch (matches PROJECT.md's stated v1.4 target features)
- P2: Should have, add once P1 lands and is validated on-device
- P3: Nice to have, deferred to a future milestone or explicitly out of scope this milestone

## Competitor Feature Analysis

| Feature | Droppy | Islet's Approach |
|---------|--------|-------------------|
| Onboarding | 4-step carousel incl. gesture tutorial (image 3) and a "Make it yours" opt-in toggle screen (image 4) | Same carousel shape minus the gesture tutorial (explicitly rejected); opt-in toggles screen not requested, defer to Settings |
| Permission pre-explanation | One-line reason per permission (Accessibility/Screen Recording/Input Monitoring) before the system prompt | Same pattern, different permission set (Bluetooth/Calendar/Location — Islet doesn't need Accessibility/Screen Recording/Input Monitoring) |
| Default expanded view | Now Playing (media-first) | Keeps Islet's existing date/time/weather/calendar glance as default — explicit PROJECT.md decision, not adopting Droppy's default |
| View switcher 3rd slot | Quick-launch apps | Calendar full view — explicit PROJECT.md decision |
| Material/visual style | Fully transparent glass ("shines more" per user's own words) | Frosted/glossy `Material` with more opacity/substance — explicit user rejection of full transparency |
| Settings structure | ~10-section sidebar incl. a plugin marketplace ("Droplets") and unrelated features (Clipboard, Basket, Cloud, Lock Screen) | 4-section sidebar scoped to what Islet actually has: General, Workspace, System, About/License |
| Calendar | Month grid + day list + "New Task" quick-add popover | Same shape (month grid + day list + quick-add), built on Islet's own EventKit service, hand-built form (no `EventKitUI` on macOS) |
| Animation feel | Deliberately variable speed, described by the user as "wie ein 360Hz Monitor" — smooth even when slow | Adopt the same target feel via tuned SwiftUI spring `response`/`dampingFraction`, optionally exposed as Animation Speed presets in v1.x |

## Sources

- Apple Developer Documentation — [`glassEffect(_:in:)`](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)) — confirms macOS 26.0+ requirement for Liquid Glass API (HIGH confidence)
- Apple Developer Documentation — [`Material`](https://developer.apple.com/documentation/swiftui/material) — SwiftUI Material thickness levels, cross-OS-version availability (HIGH confidence)
- Apple Developer Documentation — [`NSVisualEffectView`](https://developer.apple.com/documentation/appkit/nsvisualeffectview) — AppKit vibrancy primitive, confirms it operates as a system compositor layer (HIGH confidence for API existence; MEDIUM for the click-through-risk inference, which is this project's own reasoning from its Phase 20 CR-01 incident)
- Apple Developer Documentation — [`NavigationSplitView`](https://developer.apple.com/documentation/swiftui/navigationsplitview) — sidebar/detail split view, macOS 13+ (HIGH confidence)
- Apple Developer Documentation — [`EventKitUI`](https://developer.apple.com/documentation/EventKitUI), [`EKEventEditViewController`](https://developer.apple.com/documentation/eventkitui/ekeventeditviewcontroller) — no macOS/AppKit availability found in docs or examples (MEDIUM confidence — absence-of-evidence, flagged for phase-specific verification)
- WebSearch — SwiftUI `NavigationSplitView` macOS Settings-window patterns (`.toolbar(removing: .sidebarToggle)`, `.constant(.all)` columnVisibility, `@AppStorage`-persisted selection) — multiple corroborating community sources (MEDIUM confidence)
- WebSearch — macOS/mobile permission pre-prompt UX best practices (contextual timing, grant-rate improvement from pre-explanation) — multiple corroborating sources, general mobile/macOS UX consensus (MEDIUM confidence)
- WebSearch — SwiftUI `Material` vs `NSVisualEffectView` for custom glass surfaces — multiple corroborating sources (MEDIUM confidence)
- `.planning/research/inspiration/notes.md` — primary competitor reference (Droppy screenshots), the direct brief for all 4 feature areas
- `.planning/PROJECT.md` — existing Islet requirements, shipped feature history, Key Decisions (deployment target, Settings-window mechanism, prior click-through regression)
- Project memory `build-machine-macos26-toolchain.md` — confirms Islet's Settings window is already a plain `Window(id:)`, not the SwiftUI `Settings{}` scene (directly relevant to Area 3's implementation path)

---
*Feature research for: macOS notch utility app — v1.4 onboarding/Settings/theming/calendar scope*
*Researched: 2026-07-11*
