# Phase 40: Update-Available HUD & Sparkle Integration - Research

**Researched:** 2026-07-18
**Domain:** Sparkle 2 auto-update integration (SPM) + an orthogonal collapsed-pill badge in a native, non-activating LSUIElement macOS app
**Confidence:** HIGH (Sparkle API surface, entitlement precedent, badge integration point all directly verified against official docs / live GitHub API / this repo's own code). MEDIUM on Sparkle's exact LSUIElement focus-activation behavior at the moment of tapping the badge (version-dependent, not fully documented — flagged below).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Release feed & signing**
- D-01: The appcast feed (`appcast.xml`) is hosted on the user's own Vercel-deployed website domain — NOT GitHub Pages, NOT a raw GitHub URL. `SUFeedURL` in Info.plist points at that Vercel domain.
- D-02: Release binaries (`.dmg`/`.zip`) are hosted via GitHub Releases on the existing public repo (`github.com/Lippi304/notch`). The appcast's `enclosure` URLs point at the GitHub release asset, not at Vercel. Sparkle supports this feed/binary host split natively.
- D-03: This phase generates the one-time EdDSA keypair now (`generate_keys`), wires `SUPublicEDKey` into Info.plist, and keeps the private key in Keychain (never committed). It does NOT publish a real, live appcast or cut a real tagged release — verification uses a local/mock `appcast.xml`. Standing up the real Vercel route + first real signed GitHub release is separate release-prep work, out of scope.
- D-04: No new release-cadence/versioning process — `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` continue to be bumped manually per the existing `project.yml` convention.

**Update-available badge — visual design**
- D-05: Small dot/icon fixed in one corner of the collapsed capsule, visible regardless of whatever else is showing there (Charging, Device, Now Playing wings, etc.) — conceptually an app-icon badge dot, not a pill takeover.
- D-06: Collapsed-only — does NOT render in any expanded view.
- D-07: Badge color follows the existing per-element accent-theming convention (Phase 27) — no new standalone color parameter.
- D-08: Icon-only, no hover tooltip text. Tapping opens Sparkle's own dialog directly.

**Check-for-updates cadence**
- D-09: Automatic background checks enabled from the start (`SUEnableAutomaticChecks`), not deferred.
- D-10: Check interval uses Sparkle's default `SUScheduledCheckInterval` (~24h) — no custom value.
- D-11: A dedicated Settings toggle for automatic checks, following the existing `ActivitySettings` `@AppStorage`-backed toggle pattern (same shape as Focus/OSD toggles). Deliberate deviation from "no toggle, core function" — user explicitly wants a visible on/off control.
- D-12: The toggle defaults to ON — automatic checks are active immediately after install/first launch, not opt-in.

**Badge dismiss lifecycle**
- D-13: The badge persists until the update is genuinely installed — pure reflection of live pending-update state (`SPUUpdaterDelegate`'s update-available signal), not a "have I opened the dialog yet" flag. "Remind Me Later" → badge reappears on next check/launch, not dismissed on tap.
- D-14: No custom dismiss path beyond Sparkle's own dialog (Install / Remind Me Later / Skip This Version) — no extra "X" button or app-level skip mechanism.

### Claude's Discretion
- Exact SwiftUI shape/size of the badge dot and its precise corner placement within the capsule (resolved by `40-UI-SPEC.md`, approved).
- Whether the new Settings toggle (D-11) lives in the existing Theming/Activity-toggles section of `SettingsView.swift` or gets its own row (resolved by `40-UI-SPEC.md`: "Activities" section, alongside Focus/OSD toggles).
- Whether the appcast's actual XML structure/route on the Vercel site (e.g. `/appcast.xml` static file vs. an API route) is decided at planning/research time — this phase only needs a stable `SUFeedURL` value to wire against.

### Deferred Ideas (OUT OF SCOPE)
- Standing up the actual live `appcast.xml` route on the Vercel site and cutting the first real signed GitHub release — belongs to release-prep work whenever the first real update-eligible version ships (D-03).
- A custom `SPUUserDriver` replacing Sparkle's standard install/progress dialog with a fully in-notch flow — out of scope per REQUIREMENTS.md and prior research; only reconsider if the badge+standard-dialog combo proves insufficient after shipping.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| HUD-06 | An Update-available HUD appears when a new Islet version is published, backed by a real Sparkle 2 auto-update integration; tapping it triggers Sparkle's own standard install/progress dialog rather than a fully custom in-notch install flow | Standard Stack (Sparkle 2.9.4 SPM setup), Architecture Patterns (badge integration point, `AppDelegate` wiring), Common Pitfalls (SUEnableAutomaticChecks permission-prompt trap, LSUIElement focus behavior, disable-library-validation re-signing), Code Examples below |
</phase_requirements>

## Summary

This phase wires a real Sparkle 2.9.4 auto-update integration into Islet's `AppDelegate.swift` (an app-lifecycle concern, parallel to the existing `statusItem`/`menu` construction — NOT `NotchWindowController`), and adds one small orthogonal `@Published` badge overlay to the collapsed pill's outer container in `NotchPillView.swift`. Both halves are independently well-precedented in this codebase: the Sparkle SPM package embed/codeSign/disable-library-validation pattern directly mirrors the already-shipped `MediaRemoteAdapter` integration (`project.yml`), and the badge's "orthogonal `@Published` flag read directly by the view, not routed through `IslandResolver`/`TransientQueue`" shape directly mirrors the already-shipped Phase-18 song-change toast (`NowPlayingState.songChangeToast`).

The one genuinely new risk this research surfaces (not previously flagged in the v1.6 milestone research) is a **Sparkle-native permission-prompt alert**: if `SUEnableAutomaticChecks` is left unset in Info.plist, Sparkle shows its own "may Islet check for updates automatically?" alert on the app's *second* launch — an unprompted, activating window that directly violates this app's "never steals focus" design principle and conflicts with D-12's "toggle defaults ON, no prompt" decision. The fix is simple (set the Info.plist key explicitly to `true`) but easy to miss because the *runtime* property (`SPUUpdater.automaticallyChecksForUpdates`) alone does not suppress it — the check is gated on Info.plist key presence, not the live property value. This is documented below as Pitfall 1.

Everything else — the entitlement (`disable-library-validation` is already project-wide, confirmed in `Islet/Islet.entitlements`, no new entitlement needed), the badge's accent color (`env.nowPlayingAccent`, confirmed to already exist and be wired via `NotchWindowController.swift:1860`), and the exact collapsed-pill container to attach the overlay to (`NotchPillView.body`'s outer `ZStack(alignment: .top)`, confirmed at line ~761) — is already resolved by `40-CONTEXT.md`/`40-UI-SPEC.md` and directly confirmed against the live codebase in this research pass.

**Primary recommendation:** Add Sparkle 2.9.4 via SPM (embed+codeSign, reusing the existing entitlement), construct `SPUStandardUpdaterController` programmatically in `AppDelegate.applicationDidFinishLaunching` with `SUEnableAutomaticChecks` and `SUPublicEDKey` set explicitly in Info.plist, observe `SPUUpdaterDelegate.updater(_:didFindValidUpdate:)` into a new one-field `UpdateAvailableState: ObservableObject`, and render the badge as a `.overlay(alignment: .topTrailing)` on `NotchPillView.body`'s outer container, gated on `!interaction.isExpanded`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Sparkle updater lifecycle (check scheduling, download, verify, install) | App lifecycle (`AppDelegate`) | — | Sparkle's `SPUStandardUpdaterController` is an app-lifecycle concern parallel to `statusItem`/`menu`, not a notch-rendering concern (confirmed: `ARCHITECTURE.md` Integration Point 5, and this app has no server/backend tier) |
| "Check for Updates…" menu item | App lifecycle (`AppDelegate`'s `NSMenu`) | — | Same `menu.addItem`/`target = self` pattern as "Settings…"/"Quit Islet" |
| Update-available badge state (`updateAvailable: Bool`) | Notch render layer (`NotchWindowController` writes, `NotchPillView` reads) | App lifecycle (`AppDelegate` owns the `SPUUpdaterDelegate` callback that flips it) | The badge is a rendering concern (collapsed-pill overlay) but its truth source is an app-lifecycle object (`SPUUpdater`) — the delegate callback in `AppDelegate` must bridge into the notch-layer's `@Published` state, mirroring how `AppDelegate` already owns `notchController` and can reach into it |
| Automatic-check-enabled Settings toggle | Settings UI (`SettingsView.swift`) + `ActivitySettings` (`@AppStorage`) | App lifecycle (`AppDelegate` reads the stored value to set `updater.automaticallyChecksForUpdates`) | Same shape as every other `ActivitySettings` toggle — UI writes `@AppStorage`, a lifecycle/controller object reads it once at relevant points |
| EdDSA signing (private key) | Local developer machine / Keychain — NOT shipped in the app or repo | — | Signing happens at release-build time, outside the running app; the app only ever carries the *public* key (`SUPublicEDKey` in Info.plist) |
| Appcast feed hosting | External (Vercel, D-01) | — | Not part of this app's tiers at all — a static file served by infrastructure outside the codebase |
| Release binary hosting | External (GitHub Releases, D-02) | — | Same — infrastructure, not app code |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|---------------|
| **Sparkle** (`sparkle-project/Sparkle`) | **2.9.4** `[VERIFIED: GitHub API — api.github.com/repos/sparkle-project/Sparkle/releases/latest, tag_name "2.9.4", published 2026-07-03]` | Auto-update framework for direct-distributed, notarized, non-App-Store macOS apps | The de-facto standard for this exact app shape (already the project's own locked stack choice per `CLAUDE.md`/`STACK.md`). Repo confirmed `[VERIFIED: GitHub API]`: created 2009-08-11, 9,342 stars, not archived — a mature, actively-maintained, non-hallucinated dependency, not a slopsquat risk. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Sparkle's bundled `generate_keys` CLI tool | Ships inside the Sparkle SPM package artifacts (`.build`/`artifacts/sparkle/Sparkle/bin/`) `[CITED: sparkle-project.org/documentation/customization]` | One-time EdDSA keypair generation (D-03) | Run once, locally, outside the app target — never shipped as app code |
| Sparkle's bundled `generate_appcast` CLI tool | Same location | Produces a correctly-signed `appcast.xml` from a folder of release archives | Deferred — D-03 explicitly defers real appcast publishing to release-prep work outside this phase; a hand-authored mock `appcast.xml` is sufficient for this phase's own verification |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Sparkle's default `SPUStandardUpdaterController` alert UI | A fully custom `SPUUserDriver` rendering the entire install/progress flow as an in-notch HUD | Explicitly rejected — REQUIREMENTS.md's Out-of-Scope table and `FEATURES.md`/`ARCHITECTURE.md` both confirm this is disproportionate scope for a feature whose job is "tell the user an update exists," not rebuild Sparkle's UI surface. `SPUUserDriver` requires implementing ~10 callback points (permission request, download progress, extraction, ready-to-install, installing, relaunching) |
| Programmatic `SPUStandardUpdaterController` init in `AppDelegate.swift` | Interface Builder / `MainMenu.xib`-based setup (Sparkle's own docs default to this) | This project has no `.xib`/storyboard — it's a pure SwiftUI + programmatic-AppKit-shell app (matches the existing `statusItem`/menu construction pattern) `[CITED: sparkle-project.org/documentation/programmatic-setup]` |

**Installation:**
```bash
# Add via Xcode: File > Add Package Dependencies… -> https://github.com/sparkle-project/Sparkle
# OR add to project.yml's `packages:` block (matches the existing MediaRemoteAdapter entry):
#   Sparkle:
#     url: https://github.com/sparkle-project/Sparkle
#     from: 2.9.4          # Sparkle DOES have real git tags (unlike mediaremote-adapter) — `from:` resolves fine
# Target > General > Frameworks: set Sparkle.framework to "Embed & Sign" (embed: true, codeSign: true in project.yml)
```

**Version verification:** `[VERIFIED: GitHub API]` — `curl -s https://api.github.com/repos/sparkle-project/Sparkle/releases/latest` returned `tag_name: "2.9.4"`, `published_at: "2026-07-03T03:42:15Z"`, confirming this repo's `STACK.md` finding is still current as of this research pass (2026-07-18) and not stale.

## Package Legitimacy Audit

Sparkle is added via **Swift Package Manager (git URL)**, not a language package registry (npm/PyPI/crates) — `slopcheck` and `npm view`-style registry verification do not apply to this ecosystem. Verification was performed directly against GitHub, the authoritative source for an SPM git dependency.

| Package | Registry | Age | Stars | Source Repo | Verification | Disposition |
|---------|----------|-----|-------|--------------|---------------|-------------|
| `sparkle-project/Sparkle` | SPM (git URL, not a package registry) | 16 years (created 2009-08-11) `[VERIFIED: GitHub API]` | 9,342 `[VERIFIED: GitHub API]` | `github.com/sparkle-project/Sparkle` (canonical, not archived) `[VERIFIED: GitHub API]` | `slopcheck` not applicable (SPM has no central registry to hallucinate a name into); identity confirmed directly via `api.github.com/repos/sparkle-project/Sparkle` and cross-checked against this repo's own pre-existing `STACK.md`/`CLAUDE.md` recommendation (both independently arrived at the same canonical URL) | Approved |

**Packages removed due to slopcheck [SLOP] verdict:** none.
**Packages flagged as suspicious [SUS]:** none.

*`slopcheck` itself was installed and available in this environment (`/opt/homebrew/bin/slopcheck`), but its `install`/`scan` subcommands target npm/PyPI-style registries — it has no SPM-git-URL check. Verification here used the equivalent-rigor manual check the protocol prescribes for non-registry ecosystems: direct GitHub API confirmation of repo identity, age, and star count, cross-referenced against two independent prior mentions of the same canonical URL in this project's own research/CLAUDE.md.*

## Architecture Patterns

### System Architecture Diagram

```
App launch (AppDelegate.applicationDidFinishLaunching)
  │
  ├─ statusItem/menu construction (existing)
  │     └─ NEW: "Check for Updates…" NSMenuItem, target=self, action=checkForUpdates
  │
  ├─ NEW: updaterController = SPUStandardUpdaterController(
  │           startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
  │     │
  │     ├─ reads Info.plist: SUFeedURL, SUPublicEDKey, SUEnableAutomaticChecks
  │     ├─ background check (~24h, SUScheduledCheckInterval default) OR
  │     │   manual check ("Check for Updates…" tap / badge tap)
  │     │
  │     └─ on found update → SPUUpdaterDelegate.updater(_:didFindValidUpdate:)
  │           │
  │           └─ AppDelegate sets notchController.updateAvailableState.updateAvailable = true
  │                 (bridges app-lifecycle event into notch-render layer)
  │
  └─ notchController.start()  (existing)
        │
        └─ NotchPillView renders:
              presentationSwitch (existing, UNCHANGED — badge is NOT a case here)
              .overlay(alignment: .topTrailing) {
                  if updateAvailableState.updateAvailable && !interaction.isExpanded {
                      badge (tap → updaterController.checkForUpdates(nil))
                  }
              }
                 │
                 └─ tap → Sparkle's own standard alert (Install / Remind Me Later / Skip)
                       │
                       ├─ "Install" → download → verify (EdDSA) → relaunch
                       ├─ "Remind Me Later" → badge stays / reappears next check (D-13)
                       └─ "Skip This Version" → Sparkle suppresses that version internally;
                                                  badge clears (no more "valid update" found)
```

### Recommended Project Structure

No new directories. Two files touched, one new tiny file:

```
Islet/
├── AppDelegate.swift              # MODIFIED: updaterController property, menu item, SPUUpdaterDelegate conformance
├── Notch/
│   ├── NotchPillView.swift        # MODIFIED: badge overlay on body's outer ZStack
│   ├── NotchWindowController.swift # MODIFIED (small): owns/exposes UpdateAvailableState like nowPlayingState
│   └── UpdateAvailableState.swift # NEW: one-field ObservableObject, mirrors NowPlayingState's shape
├── ActivitySettings.swift         # MODIFIED: new @AppStorage key for the automatic-checks toggle (D-11)
└── SettingsView.swift             # MODIFIED: new Toggle row in the Activities section
```

### Pattern 1: Programmatic `SPUStandardUpdaterController` construction (no Interface Builder)

**What:** Sparkle's own docs default to IB/`MainMenu.xib` setup, which this project doesn't use. Construct programmatically instead, exactly like every other AppKit object in `AppDelegate.swift`.
**When to use:** Always, in this codebase — matches `statusItem`/`menu`'s existing construction style.
**Example:**
```swift
// Source: sparkle-project.org/documentation/programmatic-setup (CITED)
private var updaterController: SPUStandardUpdaterController!

func applicationDidFinishLaunching(_ notification: Notification) {
    // ... existing statusItem/menu setup ...
    updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: self,     // AppDelegate conforms to SPUUpdaterDelegate
        userDriverDelegate: nil    // nil = use Sparkle's own standard UI, no custom driver
    )

    menu.addItem(withTitle: "Check for Updates…",
                 action: #selector(checkForUpdates), keyEquivalent: "")
    // ... insert before the separator/"Quit Islet", same target=self wiring as Settings…
}

@objc private func checkForUpdates() {
    updaterController.checkForUpdates(nil)
}
```

### Pattern 2: `SPUUpdaterDelegate` bridging an app-lifecycle event into the notch-render layer's `@Published` state

**What:** `AppDelegate` (not `NotchWindowController`) owns the Sparkle delegate callback, but the badge lives in the notch-render layer — `AppDelegate` already holds a reference to `notchController`, so it reaches in to set the new state, the same way it already reaches `notchController.nowPlayingState.isHealthy` today (per the existing Quick-task-260708-u47 precedent: "not `private` so SettingsView can read the live nowPlayingState... via the standard `NSApp.delegate as? AppDelegate` idiom").
**When to use:** Any time an app-lifecycle-owned object (Sparkle, licensing) needs to influence notch rendering.
**Example:**
```swift
// Source: sparkle-project.org SPUUpdaterDelegate API reference (CITED) + this repo's own
// AppDelegate -> notchController reach-in precedent (VERIFIED: AppDelegate.swift, notchController property comment)
extension AppDelegate: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        notchController?.updateAvailableState.updateAvailable = true
    }
    // No updaterDidNotFindUpdate override needed — D-13 says the badge is a pure reflection
    // of "is there currently a valid pending update," and Sparkle simply won't call
    // didFindValidUpdate again until one exists; nothing needs to actively clear the flag
    // on a "no update found" background check EXCEPT after an actual successful install
    // (Sparkle relaunches the app on install, which resets updateAvailable to its default
    // false on next launch — no explicit clear code needed).
}
```

### Pattern 3: Badge as a `.overlay` on the collapsed pill's outer container, outside `presentationSwitch`

**What:** `NotchPillView.body` wraps `presentationSwitch` in `ZStack(alignment: .top)` (confirmed at `NotchPillView.swift:761-768`). The badge attaches as a sibling overlay on this SAME outer container, never inside any individual `presentationSwitch` case — this is what makes it render "regardless of whichever `IslandPresentation` case is currently active" (D-05) while still disappearing once expanded (D-06, gated on `interaction.isExpanded`).
**When to use:** This phase only — no other HUD in the codebase needs this "always-on-top-of-everything-collapsed" shape (confirmed unique per `ARCHITECTURE.md` Integration Point 5's classification table).
**Example:**
```swift
// Source: this repo's own NotchPillView.swift body (VERIFIED, lines 757-831) — badge added
// as a NEW modifier on the SAME container presentationSwitch already renders inside.
var body: some View {
    ZStack(alignment: .top) {
        presentationSwitch
    }
    .overlay(alignment: .topTrailing) {
        if updateAvailableState.updateAvailable && !interaction.isExpanded {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(nowPlayingAccent)
                .offset(x: -4, y: 4)
                .accessibilityLabel("Update available")
                .onTapGesture { onUpdateBadgeTap() }
        }
    }
    .frame(width: ..., height: ..., alignment: .top)   // existing frame modifiers, unchanged
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)  // unchanged
}
```
Per `40-UI-SPEC.md`: gate the overlay's *presence* (not opacity) — no badge in the view tree at all when `updateAvailable == false`, mirroring the absence-based pattern OSD/Charging already use.

### Anti-Patterns to Avoid

- **Routing the badge through `IslandResolver`/`ActiveTransient`/`TransientQueue`:** Update-available has no expiry/queue semantics — it should never occupy or evict a splash slot. Confirmed explicitly rejected in `ARCHITECTURE.md` Integration Point 2's classification table and Anti-Pattern 1. Use the orthogonal-`@Published`-field pattern instead (same as the song-change toast).
- **Building a custom `SPUUserDriver`:** Out of scope per REQUIREMENTS.md; a disproportionate lift (~10 callback points) for a feature whose job is only "notify that an update exists."
- **Wiring the Sparkle delegate callback inside `NotchWindowController`:** Sparkle is an app-lifecycle concern; `NotchWindowController` should only be handed the resulting boolean state, not own the `SPUUpdaterDelegate` conformance itself.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|--------------|-----|
| Update check scheduling, download, EdDSA signature verification, install/relaunch | A custom "check GitHub releases + download + verify + relaunch" pipeline | Sparkle's `SPUUpdater`/`SPUStandardUpdaterController` | This is exactly Sparkle's job — a mature, 16-year-old, actively-maintained framework built for precisely this app shape (direct-distributed, notarized, non-sandboxed). Hand-rolling reimplements EdDSA verification, atomic install, and relaunch-with-privilege-preservation, all genuinely hard to get right and already solved. |
| The "does the app have a pending update right now" signal driving the badge | A custom polling loop that periodically re-checks Sparkle's internal state | `SPUUpdaterDelegate.updater(_:didFindValidUpdate:)`, an event-driven callback | Sparkle already fires this exact event; polling would violate this project's own consistently-enforced "event-driven, not polling" convention (`PowerSourceMonitor`, `IslandResolver` doc comments). |
| Update-progress/install UI | A bespoke in-notch download/install progress view | Sparkle's own standard `SPUStandardUserDriver` alert | Explicitly out of scope (REQUIREMENTS.md, D-14) — Sparkle's standard dialog already handles Install/Remind Me Later/Skip and all download/verify/relaunch UI. |

**Key insight:** Every piece of this phase that touches update *mechanics* (signing, verification, download, install) should be Sparkle's code, unmodified. The only genuinely new code this phase writes is (a) the thin AppDelegate wiring, and (b) the badge's presence/color/tap-target — both of which are pure UI glue over an existing, proven mechanism.

## Common Pitfalls

### Pitfall 1: `SUEnableAutomaticChecks` unset → Sparkle shows its own unprompted permission alert on second launch, breaking "never steals focus"

**What goes wrong:** If `SUEnableAutomaticChecks` is absent from Info.plist, Sparkle does NOT default to automatic checks being simply off — it defaults to showing its own native "May [App] check for updates automatically?" permission alert the *second* time the app launches. This is a real, activating `NSAlert`-class window Sparkle presents unprompted, which directly violates this app's core design principle (never steals focus / non-activating) and conflicts with D-12 ("toggle defaults ON, active immediately, not opt-in — no such alert exists in this app's UX vocabulary").
**Why it happens:** Sparkle's permission-prompt logic is gated on whether the Info.plist key is *present at all*, not on the runtime property `SPUUpdater.automaticallyChecksForUpdates`. Setting the runtime property to `true` in code does NOT suppress the prompt — only explicitly setting the Info.plist key does. `[MEDIUM confidence — WebSearch synthesis cross-referencing Sparkle's official Customizing-Sparkle docs and a live GitHub Discussion (#2487) on the same behavior; not independently confirmed against Sparkle's own source in this pass]`
**How to avoid:** Set `SUEnableAutomaticChecks` to `true` explicitly in Info.plist (via `project.yml`'s `INFOPLIST_KEY_SUEnableAutomaticChecks: YES`, mirroring the existing `INFOPLIST_KEY_*` convention already used for `LSUIElement`/usage-description keys) — do not rely on setting `updater.automaticallyChecksForUpdates = true` in Swift alone.
**Warning signs:** An unexpected alert window appears/activates the app on the SECOND launch of a Debug or Release build during on-device verification (not the first) — this is the exact symptom.

### Pitfall 2: `SPUStandardUpdaterController`'s default alert UI activating the app on tap is *supposed* to happen — but must be the ONLY activation path

**What goes wrong:** `40-CONTEXT.md`'s Success Criterion 3 explicitly requires confirming on-device that tapping the badge/menu item does NOT otherwise break the panel's non-activating/click-through guarantees — but Sparkle's dialog itself IS allowed (and needs) to activate, since it's an explicit user-initiated action (matches the existing `openOnboardingSettings()` `NSApp.activate` precedent). The risk is a *background* check silently activating the app when the user didn't ask for anything (i.e. an automatic 24h check finding an update and popping the alert unprompted, indistinguishable in symptom from Pitfall 1).
**Why it happens:** Sparkle's LSUIElement/agent-app focus behavior has changed across major versions and isn't fully documented for the exact "silent background check finds an update" case (per prior `PITFALLS.md` research, MEDIUM confidence, version-dependent).
**How to avoid:** With `userDriverDelegate: nil` (Pattern 1 above), Sparkle's default `SPUStandardUserDriver` handles this — but verify on-device specifically: trigger a background check (not a manual tap) against the mock/local appcast and confirm the update-available signal surfaces ONLY as the collapsed-pill badge (D-13's "pure reflection" — no popup), with Sparkle's alert appearing only once the user actually taps the badge or the menu item.
**Warning signs:** The app activates/comes to the foreground on its own, with no corresponding user tap, during a background scheduled check.

### Pitfall 3: Embedded `Sparkle.framework` fails Library Validation under Hardened Runtime — but the fix is already project-wide

**What goes wrong:** `codesign` does not recurse into embedded third-party frameworks; an app + a differently-signed embedded framework under Hardened Runtime causes a Release-only launch crash (confirmed precedent: `MediaRemoteAdapter`, project memory `release-library-validation-crash`).
**Why it happens:** Ad-hoc/automatic signing gives the app and the embedded framework different Team IDs; dyld rejects the mapping under Library Validation.
**How to avoid:** `[VERIFIED: Islet/Islet.entitlements, read directly]` — `com.apple.security.cs.disable-library-validation` is ALREADY present and project-wide (added for `MediaRemoteAdapter`, confirmed in the entitlements file read this session). No new entitlement is needed for Sparkle — just replicate `project.yml`'s `embed: true` / `codeSign: true` package-dependency block for the Sparkle SPM product (exact same shape as the existing `MediaRemoteAdapter` entry).
**Warning signs:** Debug builds launch fine, Release (archived/notarized) builds crash instantly at launch with a dyld "different Team IDs" error — gate any Release-specific verification with `-configuration Release`, per this project's own established convention (project memory `release-library-validation-crash`).

### Pitfall 4: EdDSA key rotation and Developer ID signing identity rotation must never happen in the same release

**What goes wrong:** If the EdDSA private key AND the Developer ID code-signing identity both change between two consecutive releases, Sparkle has no valid trust chain to verify the update from the last-known-good version to the new one, and existing installs can't auto-update at all (users must manually redownload).
**Why it happens:** Sparkle's update verification depends on continuity of BOTH signing identities across the update chain — this is a known, previously-documented sharp edge (`PITFALLS.md`, citing Sparkle GitHub discussions #2174/#2401/#2597, issue #1521/#1605).
**How to avoid:** Not an immediate concern for THIS phase (D-03 explicitly defers any real release), but document the constraint now so future release-prep work doesn't accidentally violate it: generate the EdDSA keypair once in this phase and never regenerate it casually.
**Warning signs:** N/A for this phase — flag for the eventual release-prep phase.

## Code Examples

### Info.plist keys via `project.yml` (mirrors existing `INFOPLIST_KEY_*` convention)

```yaml
# Source: this repo's own project.yml (VERIFIED, read directly) — add alongside the existing
# INFOPLIST_KEY_LSUIElement / INFOPLIST_KEY_NS*UsageDescription entries at the Islet target's
# settings.base level.
INFOPLIST_KEY_SUFeedURL: "https://<your-vercel-domain>/appcast.xml"   # D-01 — placeholder until real domain locked at planning
INFOPLIST_KEY_SUPublicEDKey: "<base64 public key from generate_keys>" # D-03
INFOPLIST_KEY_SUEnableAutomaticChecks: YES                            # D-09/D-12, Pitfall 1 — MUST be explicit
# SUScheduledCheckInterval intentionally omitted (D-10: use Sparkle's own ~24h/86400s default)
```
*(Note: Xcode's `INFOPLIST_KEY_*` build-setting mechanism only supports plain string/bool leaf values — verify at implementation time whether `SUFeedURL`/`SUPublicEDKey` need to go through this mechanism or a literal `Info.plist` file instead, since this project currently uses `GENERATE_INFOPLIST_FILE: YES` with zero literal plist file. This is flagged as an Open Question below, not asserted as fact.)*

### `ActivitySettings` new key (D-11), mirroring the existing Focus/OSD toggle shape

```swift
// Source: this repo's own ActivitySettings.swift (VERIFIED, read directly, lines 22-26)
// Phase 40 / HUD-06 (D-11): defaults ON (D-12) — unlike Focus/OSD, this gates a background
// network check, not a system permission, so the "opt-in" convention those two use doesn't apply.
static let autoUpdateCheckKey = "activity.autoUpdateCheck"
```

```swift
// Source: this repo's own SettingsView.swift (VERIFIED pattern, read directly, lines 37-46)
@AppStorage(ActivitySettings.autoUpdateCheckKey) private var autoUpdateCheckEnabled = true  // D-12: default true
// ... in the "Activities" Section, alongside Focus Mode HUD / Replace System Volume/Brightness OSD:
Toggle("Automatically Check for Updates", isOn: $autoUpdateCheckEnabled)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|-------------------|---------------|--------|
| `SUUpdater`/`SUUpdaterDelegate` (Sparkle 1.x) | `SPUUpdater`/`SPUUpdaterDelegate`/`SPUStandardUpdaterController` (Sparkle 2.x) | Sparkle 2.0 (2020+) | `updater(_:didFindValidUpdate:)` is the CURRENT Sparkle 2 method name (confirmed live against `SPUUpdaterDelegate` API reference this session) — some search results surface it as "deprecated Sparkle 1 API" because the exact same method name/signature carried forward unchanged into `SPUUpdaterDelegate`; do not be misled into thinking a differently-named replacement exists. |
| DSA signing | EdDSA (ed25519) signing | Sparkle 2.x | DSA is deprecated; `generate_keys`/`SUPublicEDKey` is the only supported path for a new integration — this phase correctly targets EdDSA from the start (D-03). |

**Deprecated/outdated:** DSA-based update signing — not applicable here since this is a greenfield Sparkle integration for this app (no legacy DSA key to migrate from).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|-----------------|
| A1 | `SUEnableAutomaticChecks`'s Info.plist-presence-gated permission-prompt behavior (Pitfall 1) is current as of Sparkle 2.9.4 | Common Pitfalls | If Sparkle has since changed this to be gated on the runtime property instead, the extra Info.plist key is harmless (a no-op), so the risk of following this guidance even if slightly stale is low — but if NOT set and the behavior is still prompt-based, the failure mode (an unprompted activating alert) directly breaks a core app principle and a locked decision (D-12), so verify this specifically during Wave-0/on-device UAT rather than trusting it silently. |
| A2 | `INFOPLIST_KEY_SUFeedURL`/`INFOPLIST_KEY_SUPublicEDKey` resolve correctly through Xcode's `GENERATE_INFOPLIST_FILE: YES` synthesized-plist mechanism (no literal `Info.plist` file needed) | Code Examples | If this mechanism doesn't support these specific keys cleanly (e.g. they need to be under a different build-setting name, or a literal plist is required), the planner should budget a small spike task to confirm the exact `project.yml` syntax before committing to the full plan — this is also called out explicitly as Open Question 1 below. |
| A3 | Sparkle's default `SPUStandardUserDriver` (via `userDriverDelegate: nil`) behaves correctly (no silent app activation) for a BACKGROUND scheduled check in an LSUIElement app on the current Sparkle 2.9.4 / macOS 26 combination | Pattern 1, Pitfall 2 | If it silently activates on background checks (not just user-initiated taps), this would need to be caught by the phase's own on-device checkpoint (ROADMAP Success Criterion 3) before shipping — the CONTEXT.md decisions already anticipate this needs on-device confirmation, so this isn't a new risk this research introduces, just one it can't fully resolve without running the real binary. |

## Open Questions

1. **Does `INFOPLIST_KEY_SUFeedURL`/`INFOPLIST_KEY_SUPublicEDKey` work via `project.yml`'s `GENERATE_INFOPLIST_FILE: YES` synthesis, or does Sparkle's setup require a literal `Info.plist` file?**
   - What we know: Every other custom Info.plist key this project needs (`LSUIElement`, all the `NS*UsageDescription` keys) already goes through the `INFOPLIST_KEY_*` build-setting prefix successfully — `project.yml` confirms this pattern works for arbitrary custom keys, not just Apple-blessed ones.
   - What's unclear: Sparkle's own documentation examples always show these keys being added to a literal `Info.plist` file (the traditional Xcode project shape), not confirmed against the `GENERATE_INFOPLIST_FILE: YES` synthesis path this project uses.
   - Recommendation: Try the `INFOPLIST_KEY_*` prefix first (consistent with every existing key in this project) during planning/execution; if `xcodegen generate` + build doesn't pick it up, fall back to `INFOPLIST_KEY_SUFeedURL` isn't resolving → add a small literal `Info.plist` fragment merge, a well-documented XcodeGen feature (`INFOPLIST_FILE` + `infoPlist:` merge block) not currently used anywhere in this project.

2. **Exact SUFeedURL value — the real Vercel domain and route.**
   - What we know: D-01 locks the HOST (the user's Vercel domain), not a hypothetical.
   - What's unclear: The exact final URL (route: `/appcast.xml` static file vs. an API route) is explicitly left to Claude's Discretion per CONTEXT.md, and D-03 says the REAL route isn't stood up in this phase anyway — only a stable placeholder/mock is needed for wiring + verification.
   - Recommendation: Use a placeholder value (e.g. `https://<domain>/appcast.xml`) for the Info.plist key during this phase, verify against a local/mock `appcast.xml` (D-03), and flag the real domain substitution as part of the eventual release-prep work.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|--------------|------------|---------|----------|
| Xcode 16+ / `xcodebuild` | Build, sign, run | ✓ (existing project convention, `xcodegen generate` + `xcodebuild -scheme Islet`) | — (already the project's toolchain) | — |
| Network access to `github.com` at SPM-resolve time | Fetching the Sparkle SPM package | ✓ (verified this session — `curl` to `api.github.com` succeeded) | — | — |
| `disable-library-validation` entitlement | Release-build launch (Pitfall 3) | ✓ — already present project-wide `[VERIFIED: Islet/Islet.entitlements]` | — | none needed, already satisfied |
| Sparkle's `generate_keys`/`generate_appcast` CLI tools | One-time EdDSA keypair generation (D-03) | Not yet run in this repo — ships inside the SPM package artifacts once added, no separate install needed | 2.9.4 (bundled with the package) | — |
| Real Vercel `appcast.xml` route | D-01's eventual live feed | ✗ — explicitly deferred (D-03) | — | Local/mock `appcast.xml` file for this phase's own verification |
| Real tagged GitHub Release + signed binary | D-02's eventual live binary hosting | ✗ — explicitly deferred (D-03) | — | Same — mock verification only |

**Missing dependencies with no fallback:** none — every genuinely missing piece (real appcast route, real signed release) is explicitly out of this phase's scope per D-03, with an accepted mock-based fallback for verification.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest, `IsletTests` bundle target (`xcodebuild -scheme Islet`) |
| Config file | `project.yml`'s `IsletTests` target block (no separate config file) |
| Quick run command | `xcodebuild build -scheme Islet -configuration Debug` (build-only gate — see caveat below) |
| Full suite command | `Cmd-U` in Xcode (manual) — **NOT** `xcodebuild test`, per this project's own established constraint |

**Critical project-specific caveat** `[VERIFIED: project memory xcodebuild-test-headless-hang]`: `xcodebuild test` hangs in this project because tests are hosted inside the full `Islet.app`, which boots the real `NSPanel`/`MediaRemote`/`IOBluetooth` machinery — automated `xcodebuild test` runs are NOT a usable CI-style gate here. Use `build` as the automated per-task gate; route actual test execution to a manual `Cmd-U` pass in Xcode, exactly as every other phase in this project already does.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|---------------------|--------------|
| HUD-06 (Sparkle wiring) | `SPUStandardUpdaterController` constructs without crashing, "Check for Updates…" menu item present and wired | Build-only smoke check (no meaningful unit-testable pure logic here — this is framework-construction glue) | `xcodebuild build -scheme Islet -configuration Debug` | N/A — no new pure-logic file to unit test |
| HUD-06 (badge presence/absence) | Badge renders when `updateAvailable == true && !isExpanded`, absent otherwise | Manual on-device / Cmd-U (`NotchPillViewTests` precedent exists for similar collapsed-pill assertions) | `Cmd-U` in Xcode, or extend `NotchPillViewTests.swift` if a pure boolean helper is factored out | ❌ Wave 0 — no dedicated badge-visibility test exists yet; consider a tiny pure function `shouldShowUpdateBadge(updateAvailable:isExpanded:) -> Bool` (trivial, but testable per this project's own "every branch gets a test" convention) |
| HUD-06 (Release launch, entitlement) | Release build launches without a Gatekeeper/library-validation crash with Sparkle embedded | Manual, on-device, `-configuration Release` | Manual archive + launch, per Pitfall 3's own warning-sign guidance | N/A — this is inherently a Release-configuration manual check, mirrors the existing `MediaRemoteAdapter` verification precedent |
| HUD-06 (tap → Sparkle dialog, no focus-steal regression) | Tapping the badge/menu item surfaces Sparkle's dialog without breaking click-through/non-activating guarantees elsewhere | Manual on-device (ROADMAP's own Success Criterion 3) | N/A — inherently a human on-device check | N/A |

### Sampling Rate
- **Per task commit:** `xcodebuild build -scheme Islet -configuration Debug`
- **Per wave merge:** `Cmd-U` full suite in Xcode (manual, per this project's established constraint)
- **Phase gate:** Full manual `Cmd-U` pass + the 4 on-device checkpoints in the Phase Requirements → Test Map above, before `/gsd:verify-work`

### Wave 0 Gaps
- Optional: a tiny new pure function (`shouldShowUpdateBadge(updateAvailable:isExpanded:) -> Bool`) + a corresponding `UpdateAvailableStateTests.swift` or an addition to `NotchPillViewTests.swift` — the badge's visibility logic is trivial enough that this may be judged unnecessary by the planner (YAGNI), but is offered here since every other boolean-gated presentation branch in this codebase (`FocusActivityTests`, `OSDActivityTests`, `PowerActivityTests`) has a matching pure-logic test file.
- No test-framework install needed — `IsletTests` already exists and covers this project's testing conventions fully.

## Security Domain

### Applicable ASVS Categories

This is a native, single-user, non-networked-server macOS utility app — most ASVS web/API categories (session management, access control, server-side input validation) do not apply. The categories genuinely relevant to THIS phase:

| ASVS Category | Applies | Standard Control |
|----------------|---------|--------------------|
| V2 Authentication | No | Not applicable — no user accounts/login in this app |
| V3 Session Management | No | Not applicable |
| V4 Access Control | No | Not applicable — single-user local app |
| V5 Input Validation | Partial — yes | Sparkle's own appcast XML parsing and download verification are Sparkle's responsibility, not this app's; this app's own new code (the badge's boolean state) has no untrusted-input parsing surface at all |
| V6 Cryptography | Yes | EdDSA (ed25519) signing via Sparkle's own `generate_keys`/verification pipeline — **never hand-roll signature verification**; the private key MUST stay off any machine that also hosts the appcast/binaries (already documented in `PITFALLS.md`'s Security Mistakes table, restated here as a locked constraint for this phase's EdDSA generation step, D-03) |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|-----------------------|
| Malicious/tampered update artifact served from a compromised host | Tampering | EdDSA signature verification (Sparkle's own, built-in) — the app refuses to install an update whose signature doesn't match `SUPublicEDKey`. Never disable this check. |
| Compromised appcast host serving a "downgrade" to a known-vulnerable older version | Tampering | Sparkle's own version-comparison logic refuses installs that aren't a genuine upgrade (standard Sparkle behavior, no custom code needed) |
| EdDSA private key leaked via being stored alongside the public appcast/binaries on the same host | Information Disclosure / Elevation of Privilege | Private key lives ONLY in the local developer's Keychain, never uploaded to Vercel or GitHub Releases (D-03's own wording: "keeps the private key in Keychain, never committed to the repo") — this phase's own EdDSA generation step must follow this, not just document it |
| Sparkle's embedded framework failing Library Validation and forcing a validation-disabled state that's broader than needed | Elevation of Privilege (theoretical) | The existing `disable-library-validation` entitlement is already scoped as narrowly as Hardened Runtime allows (it's a coarse, app-wide toggle — Apple provides no per-framework scoping) — this is an accepted, already-reviewed tradeoff from the `MediaRemoteAdapter` precedent, not a new risk this phase introduces |

## Sources

### Primary (HIGH confidence)
- `api.github.com/repos/sparkle-project/Sparkle/releases/latest` — direct GitHub API query this session, confirmed `2.9.4` / published 2026-07-03 `[VERIFIED]`
- `api.github.com/repos/sparkle-project/Sparkle` — direct GitHub API query, confirmed repo age (created 2009-08-11), 9,342 stars, not archived `[VERIFIED]`
- `Islet/Islet.entitlements` — read directly this session, confirmed `disable-library-validation` already present project-wide `[VERIFIED]`
- `Islet/AppDelegate.swift` — read directly this session, confirmed exact `statusItem`/`menu` construction pattern to mirror `[VERIFIED]`
- `Islet/Notch/NotchPillView.swift` — read directly this session, confirmed exact `body`/`presentationSwitch` structure (lines 715-831) and the `nowPlayingAccent` environment key (line 132) `[VERIFIED]`
- `Islet/ActivitySettings.swift` — read directly this session, confirmed exact `@AppStorage` key convention and `EnvironmentKey`/`nowPlayingAccent` wiring `[VERIFIED]`
- `Islet/SettingsView.swift` — read directly this session, confirmed exact Toggle/Section pattern for Focus/OSD toggles (lines 37-220) `[VERIFIED]`
- `project.yml` — read directly this session, confirmed exact `packages:`/`embed: true`/`codeSign: true` pattern for `MediaRemoteAdapter`, to be replicated for Sparkle `[VERIFIED]`
- `sparkle-project.org/documentation/programmatic-setup/` — `SPUStandardUpdaterController(startingUpdater:updaterDelegate:userDriverDelegate:)` exact signature `[CITED]`
- `sparkle-project.org/documentation/api-reference/Protocols/SPUUpdaterDelegate.html` — confirmed `updater(_:didFindValidUpdate:)` is the current Sparkle 2 method name `[CITED]`
- `sparkle-project.org/documentation/customization/` — `SUFeedURL`/`SUPublicEDKey`/`SUEnableAutomaticChecks`/`SUScheduledCheckInterval` Info.plist keys, `generate_keys` tool existence `[CITED]`

### Secondary (MEDIUM confidence)
- WebSearch synthesis of Sparkle's `SUEnableAutomaticChecks` permission-prompt-on-second-launch behavior, cross-referencing the official Customizing Sparkle docs and GitHub Discussion #2487 — the specific mechanism (Info.plist-presence-gated, not runtime-property-gated) was not independently confirmed against Sparkle's own source code in this pass `[flagged as Assumption A1]`

### Tertiary (LOW confidence)
- None used without cross-verification in this pass — all WebSearch findings above were cross-checked against at least one official-docs source or this repo's own code.

### Carried from prior v1.6 milestone research (already HIGH/MEDIUM confidence, not re-verified line-by-line this session but spot-checked where load-bearing)
- `.planning/research/STACK.md` §4 "Sparkle auto-update"
- `.planning/research/ARCHITECTURE.md` §"Integration Point 5 — Sparkle Integration"
- `.planning/research/PITFALLS.md` §"Pitfall 3: Sparkle in a non-activating, LSUIElement (accessory) app"
- `.planning/research/FEATURES.md` — Update-available HUD scoping rationale

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Sparkle version/repo identity directly verified via GitHub API this session, integration pattern directly verified against this repo's own existing `MediaRemoteAdapter` precedent
- Architecture: HIGH — badge integration point (exact line numbers, exact existing `nowPlayingAccent` wiring) directly confirmed by reading the live code this session, not inferred from prior research alone
- Pitfalls: MEDIUM-HIGH — the entitlement/Library-Validation pitfall is HIGH (directly verified, already-solved in this repo); the `SUEnableAutomaticChecks` permission-prompt pitfall is MEDIUM (WebSearch-synthesized, not confirmed against Sparkle's own source, flagged as Assumption A1) and is new information this research pass surfaced beyond what the prior v1.6 milestone research already found

**Research date:** 2026-07-18
**Valid until:** 2026-08-17 (30 days — Sparkle is a stable, slow-moving dependency; re-verify the exact 2.9.4 pin and the `SUEnableAutomaticChecks` behavior if this phase's planning/execution slips past that window)
