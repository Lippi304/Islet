# Phase 40: Update-Available HUD & Sparkle Integration - Context

**Gathered:** 2026-07-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Wire a real Sparkle 2 auto-update integration into Islet (SPM dependency, embedded/signed framework, EdDSA-signed appcast, `SPUStandardUpdaterController` + "Check for Updates…" status-item menu entry) and surface a persistent, non-expiring "update available" badge on the collapsed island. The badge is an orthogonal `@Published` flag — NOT a `TransientQueue`/`ActiveTransient` participant, since it never expires on its own. Tapping the badge triggers Sparkle's own standard install/progress dialog (not a custom in-notch install flow). This phase covers wiring and entitlements only — no real appcast is published live as part of this phase (see D-03).

</domain>

<decisions>
## Implementation Decisions

### Release feed & signing
- **D-01:** The appcast feed (`appcast.xml`) is hosted on the user's own Vercel-deployed website domain — NOT GitHub Pages, NOT a raw GitHub URL. `SUFeedURL` in Info.plist points at that Vercel domain.
- **D-02:** Release binaries (`.dmg`/`.zip`) are hosted via GitHub Releases on the existing public repo (`github.com/Lippi304/notch`) — Vercel's hobby-plan bandwidth limits make it unsuited for repeated large-binary downloads; GitHub Releases has no such risk. The appcast's `enclosure` URLs point at the GitHub release asset, not at Vercel. Sparkle supports this split (feed and binaries on different hosts) natively.
- **D-03:** This phase generates the one-time EdDSA keypair now (Sparkle's `generate_keys` tool), wires `SUPublicEDKey` into Info.plist, and keeps the private key in Keychain (never committed to the repo). But it does NOT publish a real, live appcast or cut a real tagged release as part of this phase — verification uses a local/mock `appcast.xml`. Standing up the actual Vercel `appcast.xml` route + first real signed GitHub release is separate release-prep work, out of this phase's scope.
- **D-04:** No new release-cadence/versioning process — `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` continue to be bumped manually per the existing `project.yml` convention.

### Update-available badge — visual design
- **D-05:** The badge is a small dot/icon fixed in one corner of the collapsed capsule. It stays visible regardless of whatever else is currently showing there (Charging, Device, Now Playing wings, etc.) — conceptually similar to an app-icon badge dot, not a full pill takeover like the existing transient HUDs (Charging/Device/Focus/OSD).
- **D-06:** Collapsed-only. The badge does NOT render in any expanded view (Home/Calendar/Weather/Tray/switcher row) — once the user expands, focus is on that view's content, no extra element needed.
- **D-07:** Badge color follows the existing per-element accent-theming convention (Phase 27) — no new standalone color parameter, no fixed/theme-independent color.
- **D-08:** Icon-only, no hover tooltip text. Tapping opens Sparkle's own dialog directly, which explains itself — matches the app's existing minimal/Droppy-style visual language.

### Check-for-updates cadence
- **D-09:** Automatic background checks are enabled from the start (Sparkle's `SUEnableAutomaticChecks`), not deferred to a later phase.
- **D-10:** Check interval uses Sparkle's default `SUScheduledCheckInterval` (~24h) — no custom value.
- **D-11:** A dedicated Settings toggle for automatic checks is added, following the existing `ActivitySettings` `@AppStorage`-backed toggle pattern (same shape as the Focus/OSD-suppression toggles). This is a deliberate deviation from "no toggle, core function" — the user explicitly wants a visible on/off control.
- **D-12:** The toggle defaults to ON — automatic checks are active immediately after install/first launch, not opt-in.

### Badge dismiss lifecycle
- **D-13:** The badge persists until the update is genuinely installed — it is a pure reflection of live pending-update state (`SPUUpdaterDelegate`'s update-available signal), not a "have I opened the dialog yet" flag. If the user picks "Remind Me Later" in Sparkle's own dialog, the badge reappears on the next check/launch rather than disappearing on tap.
- **D-14:** No custom dismiss path beyond Sparkle's own dialog (Install / Remind Me Later / Skip This Version) — no extra "X" button or app-level skip mechanism on the badge itself. Sparkle owns the full decision logic end to end.

### Claude's Discretion
- Exact SwiftUI shape/size of the badge dot and its precise corner placement within the capsule — implementation detail, no existing precedent to match (the closest precedent, the Phase 18 song-change toast, is one-shot and mutually exclusive with other content, not analogous here).
- Whether the new Settings toggle (D-11) lives in the existing Theming/Activity-toggles section of `SettingsView.swift` or gets its own row — same discretion precedent as Phase 38/39's toggle placement.
- Whether the appcast's actual XML structure/route on the Vercel site (e.g. `/appcast.xml` static file vs. an API route) is decided at planning/research time — this phase only needs a stable `SUFeedURL` value to wire against.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope & requirements
- `.planning/ROADMAP.md` §"Phase 40: Update-Available HUD & Sparkle Integration" — the 4 success criteria this phase must satisfy
- `.planning/REQUIREMENTS.md` — HUD-06 (the requirement itself), plus the "In Scope" note ("HUD-06 only needs the 'available' notification, not the whole install UX") and "Out of Scope" table (no full custom Sparkle install/progress flow)

### Research (v1.6 milestone research, already covers this phase in depth)
- `.planning/research/STACK.md` §4 "Sparkle auto-update" — version pin (2.9.4), SPM install, `SPUStandardUpdaterController`, LSUIElement compatibility confirmation, disable-library-validation re-signing note, EdDSA signing requirement, appcast hosting discussion
- `.planning/research/ARCHITECTURE.md` §"Integration Point 5 — Sparkle Integration" — where the code lives (`AppDelegate.swift`), the orthogonal-badge pattern recommendation, why NOT to build a full custom `SPUUserDriver`
- `.planning/research/PITFALLS.md` §"Pitfall 3: Sparkle in a non-activating, LSUIElement (accessory) app" — the focus-stealing tension between Sparkle's default alert UI and Islet's "never steals focus" principle; ROADMAP's Success Criterion 3 already resolves this (Sparkle's standard dialog is allowed to activate ONLY on the explicit user tap)
- `.planning/research/FEATURES.md` — scoping rationale for shipping Sparkle's standard alert UI + a simple badge instead of a full custom `SPUUserDriver`
- `.planning/research/SUMMARY.md` — cross-doc synthesis, confirms Sparkle floats independently of other v1.6 phases

### Existing entitlement/embed precedent to mirror
- `project.yml` — the `MediaRemoteAdapter` package/`embed: true`/`codeSign: true` pattern (lines ~25-49) to replicate for the Sparkle SPM package
- `Islet/Islet.entitlements` — already carries `com.apple.security.cs.disable-library-validation` (added for `MediaRemoteAdapter.framework` under Hardened Runtime, see memory `release-library-validation-crash`); this entitlement is project-wide and already covers an embedded Sparkle.framework too, no new entitlement key needed

### Integration points in code
- `Islet/AppDelegate.swift` — owns `statusItem`/`menu` (lines 25-58); this is where the Sparkle updater controller is created and the "Check for Updates…" menu item is added, following the exact same `menu.addItem(...)` + `item.target = self` pattern already used for "Settings…"/"Quit Islet"
- `Islet/Notch/IslandResolver.swift` — the `TransientQueue`/`ActiveTransient`/`IslandPresentation` machinery this badge is explicitly NOT part of; read the file header comments (D-02/D-04/D-05 etc.) to understand why the badge must stay orthogonal rather than becoming a new resolver case
- `Islet/Notch/NotchWindowController.swift` (`songChangeToast` field, e.g. lines ~799, ~1416, ~1913, ~2057-2062) — the existing precedent for a one-shot orthogonal `@Published` field read directly by the view, driven by its own gate function (`songChangeToastGate`) rather than the resolver; the update badge follows this same "orthogonal field the view reads directly" shape but WITHOUT the auto-dismiss timer (D-13)
- `Islet/ActivitySettings.swift` — existing `@AppStorage`-backed toggle pattern to follow for the new automatic-checks Settings toggle (D-11)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Islet/AppDelegate.swift`'s existing `NSMenu`/`NSStatusItem` construction — the Sparkle "Check for Updates…" item slots in directly beside "Settings…"/"Quit Islet"
- `Islet/ActivitySettings.swift`'s `@AppStorage` toggle convention — reused as-is for the new automatic-checks toggle (D-11)
- The Phase 18 song-change toast's "orthogonal `@Published` field + dedicated gate function" pattern — direct structural precedent for the badge, minus the auto-dismiss timer

### Established Patterns
- `IslandResolver.swift`'s `resolve()` is the SINGLE arbiter for anything that competes for the collapsed pill's content (Charging/Device/Focus/OSD/Now-Playing) — the update badge deliberately stays OUTSIDE this system since it never "wins" or "loses" a slot, it overlays
- Per-element accent theming (Phase 27) is the established way to color any new visual element — D-07 follows this rather than introducing a new color axis
- `project.yml`'s SPM-package + `embed: true`/`codeSign: true` + `disable-library-validation` combo is now a proven two-time pattern (MediaRemoteAdapter, now Sparkle) for embedding third-party frameworks under Hardened Runtime

### Integration Points
- `Islet/AppDelegate.swift applicationDidFinishLaunching` — Sparkle's `SPUStandardUpdaterController` is constructed here, parallel to `statusItem`/`menu`/`notchController` construction, per `ARCHITECTURE.md`'s Integration Point 5
- Wherever the collapsed pill's view hierarchy renders today (`NotchPillView.swift`) — the badge overlay needs a render point that isn't inside any of the existing `IslandPresentation` case bodies, since it must show regardless of which case is active

</code_context>

<specifics>
## Specific Ideas

- User's own Vercel-hosted website is the intended long-term home for the appcast feed — this is a specific, concrete piece of infrastructure the user already has and wants used, not a hypothetical future site.
- The user explicitly deferred the hosting-split decision to Claude's judgment ("tell me what's better") — the GitHub-Releases-for-binaries / Vercel-for-feed split (D-01/D-02) was Claude's recommendation, confirmed by the user, not a pre-existing preference.

</specifics>

<deferred>
## Deferred Ideas

- Standing up the actual live `appcast.xml` route on the Vercel site and cutting the first real signed GitHub release — explicitly out of this phase (D-03), belongs to release-prep work whenever the first real update-eligible version ships.
- A custom `SPUUserDriver` replacing Sparkle's standard install/progress dialog with a fully in-notch flow — explicitly out of scope per REQUIREMENTS.md and research (FEATURES.md/ARCHITECTURE.md); only reconsider if the badge+standard-dialog combo proves insufficient after shipping.

### Reviewed Todos (not folded)
None — no pending todos matched this phase's scope (`cross_reference_todos` returned 0 matches).

</deferred>

---

*Phase: 40-Update-Available HUD & Sparkle Integration*
*Context gathered: 2026-07-17*
