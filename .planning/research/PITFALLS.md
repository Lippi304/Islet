# Pitfalls Research — v1.6 (Liquid Glass & System HUD Suite)

**Domain:** Native macOS notch-overlay background agent — adding OSD suppression, Focus Mode detection, Sparkle auto-update, custom blur material, and a dual-activity resolver to an existing single-winner `IslandResolver` architecture (Islet)
**Researched:** 2026-07-15
**Confidence:** MEDIUM-HIGH — grounded in the actual open-source code of the app this milestone is cloning (Droppy, `github.com/1of1Adam/Droppy`, GPL-3.0+Commons-Clause, live 2026 source), plus Sparkle's official docs/issues and this project's own prior WR-01/WR-02 findings.

## Risk-Tier Summary (read this first)

| # | Feature | Risk Tier | Verdict |
|---|---------|-----------|---------|
| 1 | Volume/Brightness HUD suppression | **HIGH** | Achievable — Droppy ships it today — but fragile, permission-gated, and has a documented macOS-Tahoe-specific breakage mode. Needs a spike before committing scope. |
| 2 | Focus Mode / DND detection | **HIGH** | Achievable only via an undocumented file + Full Disk Access, a manual, unprompted, easily-declined TCC grant. Real UX cost, real breakage risk. Needs a spike + an explicit "what if the user says no" fallback design before committing scope. |
| 3 | Sparkle in an LSUIElement app | MEDIUM | Well-trodden path, Sparkle has explicit LSUIElement support, but multiple sharp edges (activation/focus behavior changed across Sparkle versions, EdDSA setup, key rotation). Standard research-and-follow-the-docs, not a spike. |
| 4 | Liquid Glass / frosted material | MEDIUM | SwiftUI gives you the materials for free; the risk is entirely self-inflicted (this project already broke `matchedGeometryEffect` continuity once — WR-02 — doing exactly this class of change). |
| 5 | Dual-activity display (2-slot resolver) | MEDIUM | No private API involved, pure architecture problem. Real complexity: race conditions, two `matchedGeometryEffect` groups, combinatorial test growth. Solvable with discipline. |
| 6 | 7+ new HUD types in/around the resolver | MEDIUM (self-inflicted if ignored) | Pure software-engineering risk — the codebase already has the right pattern (`IslandResolver`); the pitfall is bypassing it under time pressure. |
| 7 | Calendar countdown HUD (per-minute, up to 1hr) | LOW | This project already has the exact convention needed (event-driven, idle-CPU-gated, as in `EqualizerBars`). Straightforward if the existing convention is followed. |

**Bottom line for roadmap sequencing:** Items 1 and 2 are the ones that could fail to ship as designed on current macOS and should get a dedicated research/spike phase *before* any UI work is planned around them — exactly as `v1.6`'s own `Key context` note in PROJECT.md already flags. Items 3–6 are normal feature phases with known-sharp-edges to design around up front. Item 7 needs no special phase treatment beyond following the project's existing timer-hygiene convention.

---

## Critical Pitfalls

### Pitfall 1: Volume/Brightness OSD suppression — wrong event-tap variant breaks transport keys on this exact macOS version

**What goes wrong:**
There is no public API to suppress `com.apple.OSDUIHelper`'s system HUD. The only known working technique — used today by the reference app Droppy (`Droppy/MediaKeyInterceptor.swift`) — is a `CGEvent.tapCreate` on `CGEventType.systemDefined` (raw value 14) events, decoding `NX_SYSDEFINED`/`NX_SUBTYPE_AUX_CONTROL_BUTTONS` key codes for volume/brightness, and returning `nil` from the callback to swallow the event system-wide (which prevents `OSDUIHelper` from ever seeing it and spawning its HUD). Droppy's own source comments record that using `.cgAnnotatedSessionEventTap` (rather than `.cgSessionEventTap`) **breaks play/pause/next/previous transport controls on macOS Tahoe** — it intercepts those events before they reach the media subsystem even when the app tries to pass them through. This project's build/dev machine is confirmed macOS 26 (Tahoe), so this is not a hypothetical edge case — it is the exact OS in use.

**Why it happens:**
Apple offers two tap variants (`cgSessionEventTap` and the "annotated" variant) with subtly different event-delivery-order semantics that aren't documented for this specific interaction, and that semantics can silently change release-to-release. Developers reach for whichever tap variant a tutorial shows without testing the transport-key path specifically.

**How to avoid:**
- Use `CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: ...)` — not the annotated variant — and explicitly test all 4 transport keys (play/pause, next, previous/rewind) plus volume/brightness after wiring the tap, on the actual dev machine's macOS version.
- Explicitly allowlist which `NX_KEYTYPE_*` codes are handled (`SOUND_UP/DOWN/MUTE`, `BRIGHTNESS_UP/DOWN`) and immediately pass through anything else (especially `PLAY`/`FAST`/`REWIND`/`PREVIOUS`) without any processing — do not run them through the same suppress/pass-through decision path as volume/brightness.
- Requires **Accessibility** permission (System Settings → Privacy & Security → Accessibility), not just Input Monitoring — `CGEvent.tapCreate` with `.defaultTap` (able to consume/suppress events, not just observe) needs it. Gate `start()` on a cached permission check; don't silently no-op if denied.
- Fall back to system handling for devices Islet can't control (e.g. USB audio interfaces without software volume control) — check `supportsVolumeControl`/`canHandleBrightness` before consuming the key event, otherwise the user loses volume control entirely on unsupported hardware.
- Isolate all of this behind one `VolumeHUDInterceptor`/`BrightnessHUDInterceptor` protocol, exactly like the project's existing `NowPlayingMonitor` pattern — this is the single most likely thing Apple disrupts in a future OS.

**Warning signs:**
- Play/pause or track-skip stops working system-wide (not just in Islet) after this feature ships — the classic annotated-tap symptom.
- Two HUDs briefly flash (system's + Islet's) — indicates the event tap is winning the suppression race too late or the callback is running on a contended thread (Droppy's own history notes a "double HUD on M4 Macs" bug fixed by moving the tap's run loop off the main thread onto a dedicated `DispatchQueue`).
- App becomes unresponsive to media/volume/brightness keys entirely after a permission change — indicates the tap-disabled-by-timeout/by-user-input callback path isn't correctly re-checking permission before blindly re-enabling (a naive re-enable-on-disable loop can fight the system and freeze the WindowServer).
- `NSEvent(cgEvent:)` constructed off the main thread when Caps Lock is involved crashes via Text Services Manager assertion — extract event data on the main thread (`DispatchQueue.main.sync`) inside the C callback, not off it.

**Phase to address:**
Dedicated research/spike phase before UI work — validate the tap variant, permission flow, and transport-key passthrough on-device first; this is exactly the kind of unknown PROJECT.md already flags for a research phase.

---

### Pitfall 2: Focus Mode / DND detection has no supported API — the only path costs the user a manual, unprompted Full Disk Access grant

**What goes wrong:**
Apple's only semi-official third-party Focus API is `INFocusStatusCenter`/`FocusStatusCenter` (`isFocused`), which is scoped to communication/VoIP-style apps for suppressing notification interruptions — it tells you "is the user in *some* focus state," gated behind `requestAuthorization`, and does **not** expose which Focus Mode is active or a live per-mode toggle stream suitable for driving a HUD. It is the wrong tool for "show a HUD when the user turns Focus on/off." The only method that actually works today (confirmed by Droppy's live source, `Droppy/DNDManager.swift`) is polling the undocumented file `~/Library/DoNotDisturb/DB/Assertions.json` and checking whether `storeAssertionRecords` is non-empty. This file lives under **Full Disk Access** protection — there is no programmatic TCC prompt for Full Disk Access; the user must manually open System Settings → Privacy & Security → Full Disk Access and add the app themselves, with zero in-app nudge Apple will show automatically.

**Why it happens:**
Apple has publicly said (per multiple community reports) that a real third-party Focus API is coming "eventually," but as of macOS 26 it still doesn't exist for this use case. Developers assume `NSStatusItem`'s `Visible FocusModes`/`Visible DoNotDisturb` plist keys (in `com.apple.controlcenter.plist`) are a shortcut — they are not reliable, since the focus menu-bar icon can be visible even when no Focus is actually active.

**How to avoid:**
- Do not build this against `INFocusStatusCenter` expecting it to report per-mode state — it can't.
- Plan for Full Disk Access as a real, separate onboarding step with its own explanation UI (why Islet needs it, a deep link to the System Settings pane) — do not silently gate the feature behind a permission the user was never told about.
- Design an explicit degraded path for "permission denied/not granted": the Focus HUD feature must silently not exist rather than crash or spin — mirror the project's existing "any column degrades silently to absent on permission denial" convention from the Phase 14 weather/calendar work.
- Poll, don't assume push notifications exist for this file — there is no `NSDistributedNotificationCenter` event for Focus changes; Droppy polls every 0.5s via a `DispatchSourceTimer`. Treat the poll interval as a tunable tradeoff (see Pitfall 7 / idle-CPU discussion) rather than copying 0.5s uncritically.
- Isolate behind one `FocusModeMonitor` protocol — this is squarely in "next thing Apple might restrict further" territory (Full Disk Access grants are exactly the kind of surface Apple tightens release over release).

**Warning signs:**
- Feature works in your dev environment (because Full Disk Access was already granted for other tooling) but silently does nothing for a fresh install — the #1 way this pitfall goes undetected until a real user reports it.
- JSON parse of `Assertions.json` throws/returns empty during a Focus *transition* (not just off) — the file can be transiently in a shape that doesn't match the expected schema; treat a parse failure as "no data yet," not "Focus is off."

**Phase to address:**
Dedicated research/spike phase before UI work — this is the highest-uncertainty item in the whole milestone; confirm the Full Disk Access UX is acceptable to the user (it requires explaining a fairly scary-sounding permission for what looks like a small feature) before committing to it as scoped, and have a documented fallback/descope plan if it's rejected.

---

### Pitfall 3: Sparkle in a non-activating, LSUIElement (accessory) app — update UI can appear behind everything or never focus

**What goes wrong:**
Sparkle's behavior toward accessory/background apps has changed across versions: older Sparkle releases had the update-available window silently open behind the user's other windows for apps without a Dock icon (a real filed issue: "Updater Window sometimes hidden by main application window"); more recent Sparkle explicitly "focuses \[LSUIElement apps] before displaying the update alert," but even more recent behavior notes show the opposite tension — showing the update window *behind* other apps rather than stealing focus, to avoid an agent app rudely interrupting the user. Because Islet's entire design principle is "never steals focus, non-activating panel," pulling in Sparkle's default alert UI is a values collision: Sparkle's dialog *does* need to activate and focus itself when the user needs to act on it (approve an install), which conflicts with everything else in this app's window model.

**Why it happens:**
Sparkle is designed primarily for normal Dock-icon apps; LSUIElement support is a secondary path that has been patched over time rather than designed in from the start, so its exact activation semantics are version-dependent and easy to get wrong by pinning an old tutorial's setup code.

**How to avoid:**
- Pin to a current Sparkle 2.x release and read the CHANGELOG for the specific LSUIElement-focus-behavior entries before wiring it up — don't copy a Stack Overflow snippet from an older major version.
- Decide explicitly (as a design decision, not a default): should Islet's own "Update-available HUD" replace Sparkle's default alert entirely (driving `SPUUpdater` programmatically and only using Sparkle for the download/verify/install machinery), or should Sparkle's native dialog be allowed to activate the app the one time it truly needs user attention? Given the project's hard "never steals focus" rule, the former (custom UI driving `SPUUpdaterDelegate`, suppressing Sparkle's own UI) is the more consistent choice — but it's real extra integration work, not a checkbox.
- `SPUUpdater`/`SPUStandardUpdaterController` needs `NSApplicationActivationPolicy` correctly set (`.accessory` for Islet); test that "Check for Updates" and the install-and-relaunch flow both work correctly with no Dock icon and no menu bar app menu present — a bare LSUIElement app has no standard "Sparkle" menu item host by default and needs one wired manually (e.g., via the existing status-item menu).

**Warning signs:**
- Update dialog appears but pointer/keyboard focus stays on whatever app was frontmost — user doesn't notice an update is available.
- App silently installs an update while fullscreen/DND is active, in a way that visually interrupts — mirror the existing fullscreen-suppression convention used for activities.

**Phase to address:**
Normal feature phase — well-documented territory, budget time for reading current Sparkle docs/changelog rather than trusting older tutorials, and for an explicit focus-policy decision up front.

---

### Pitfall 4: Custom blur/frosted material re-triggers the exact `matchedGeometryEffect` continuity break this project already hit once (WR-02)

**What goes wrong:**
PROJECT.md's own tech-debt log records WR-02: "accent-change view-tree rehost breaking `matchedGeometryEffect` continuity" from Phase 27's theming work. Swapping the background material (gradient → frosted/blurred "Liquid Glass") is the same category of change: if the new material is implemented as a *different view type* (e.g., swapping `Rectangle().fill(gradient)` for an `NSVisualEffectView`-backed material or a differently-structured `.background(.ultraThinMaterial)` modifier chain) rather than a value-only change to an *existing* view in the same position in the view tree, SwiftUI will treat it as inserting/removing a view identity — which breaks the `matchedGeometryEffect` morph between collapsed and expanded states (the single most important visual trick in this app) instead of animating it.

**Why it happens:**
Material/blur effects in SwiftUI are commonly reached for via `.background(Material)`/`NSVisualEffectView` wrapped in a new `NSViewRepresentable`, which is structurally a different node in the view tree than a plain `Shape.fill(...)`. Developers focus on getting the visual right in isolation and only discover the morph is broken once it's live in the full collapsed↔expanded flow.

**How to avoid:**
- Apply the new material as a **modifier on the existing shape/view that already carries the `matchedGeometryEffect` id** (e.g., `.fill()` → `.background(Material, in: shape)` on the *same* `RoundedRectangle`/`Capsule` node), not as a new sibling/wrapper view.
- If an `NSVisualEffectView`-backed representable is unavoidable (true frosted-glass blur, not just a SwiftUI `Material`), host it *underneath* the shape that owns the `matchedGeometryEffect` id (as a background layer) rather than making it the animated node itself.
- Regression-test exactly the same 7-point on-device checklist Phase 25 already used for the gradient material change (gradient/material depth, corner roundness, spring feel, no morph artifacts, rapid hover-enter/exit, activity-content regression) — this is the proven verification method for this exact class of change in this codebase.

**Warning signs:**
- The pill visually "pops"/cross-fades between collapsed and expanded instead of morphing — the signature symptom of a broken `matchedGeometryEffect` pairing.
- Material renders correctly at rest but glitches only during the spring animation — indicates the material view is being recreated mid-animation rather than persisting.

**Phase to address:**
The material redesign phase itself — treat the Phase-25-style on-device UAT checklist as a hard gate before merging, not an optional nice-to-have.

---

### Pitfall 5: Extending `IslandResolver` to a two-slot (main + secondary bubble) model races two independently-updating activities and doubles the `matchedGeometryEffect` surface

**What goes wrong:**
Today's `IslandResolver` is a pure, ranked, single-winner reduce over independently-updating sources (Charging/Device/Now Playing/etc. each publish state changes on their own timers/callbacks) feeding one `TransientQueue`. A dual-activity model (main pill + secondary bubble) means **two** activities can be independently live and independently updating at once — e.g., a calendar countdown ticking every minute while a song changes — and the resolver now has to decide not just "who wins" but "who's primary vs. secondary, and what happens when the secondary activity itself changes/ends while the primary is unaffected." This is a materially different problem than the existing 14+ single-winner tests cover, and naive extension (e.g., "just also track a second `TransientQueue` in parallel") reintroduces races: two independent publishers can both mutate resolver state in the same runloop tick, and depending on evaluation order the secondary bubble can flicker, show stale content, or briefly show the wrong activity as primary.

**Why it happens:**
It's tempting to treat "dual activity" as "run the existing single-winner logic twice," but the two slots are not independent — promotion/demotion between primary and secondary needs a single, ordered decision point (same discipline as the current one-arbiter design), or you end up with two arbiters that can disagree.

**How to avoid:**
- Keep the "one pure arbiter" principle intact: extend `IslandResolver`'s output type from a single winner to a small ordered structure (e.g., `(primary: Activity?, secondary: Activity?)`) computed by **one** reduce pass over all live activities, not two independent resolver instances.
- Explicitly define and test the promotion rules as data, not scattered conditionals: what happens when the primary activity ends while a secondary is live (secondary promotes)? When a new activity outranks the current secondary but not the primary? When both slots would resolve to the same activity?
- Two `matchedGeometryEffect` groups (one per slot) need **distinct namespaces**, not just distinct ids within one namespace — reusing one shared `@Namespace` across both slots risks SwiftUI picking an unintended source/target pairing across slots (a documented `matchedGeometryEffect` failure mode when multiple views compete for the same id+namespace).
- Grow the test suite proportionally: the existing single-winner suite (14+ tests) should not just gain a few new cases — expect roughly a combinatorial expansion (each existing single-activity scenario × "with/without a concurrent second activity" × promotion/demotion transitions) to actually cover the new state space.

**Warning signs:**
- Secondary bubble briefly shows the wrong activity's content for one frame during a transition — an ordering race between two independent state updates landing in the same animation tick.
- Primary and secondary bubble momentarily show the *same* activity — a symptom of the "distinct ids per slot" invariant not being enforced.

**Phase to address:**
Its own phase, sequenced after the single-HUD types are proven, not combined with them — the resolver extension is independently risky enough to isolate (matches this project's own established pattern of isolating the one genuinely uncertain integration point per phase, as done with Phase 22's drag-in spike).

---

### Pitfall 6: Adding 7+ new HUD types as scattered if-chains instead of through `IslandResolver` reintroduces the exact bug class the resolver was built to prevent

**What goes wrong:**
`IslandResolver` exists specifically because pre-Phase-6 priority logic was scattered across the view/controller layer and produced real defects (WR-1/WR-2, identity-match and dismiss-timer bugs, closed in gap-closure). Adding 7 new HUD types (Volume, Brightness, Focus, Update-available, Bluetooth/AirPods restyle, Charging restyle, Drop-session summary, Calendar countdown) under time pressure creates strong temptation to special-case a few of them directly in the view layer ("just show the Update HUD whenever `updateAvailable == true`, bypassing the queue, because it's simple") — which is exactly the anti-pattern the resolver prevents. Once even one HUD type bypasses the arbiter, the "one pure arbiter" invariant is broken and every future interaction between that HUD and everything else has to be reasoned about ad hoc.

**Why it happens:**
Some of the new HUDs feel "too simple to need the full resolver machinery" (a one-shot toast like the drop-session summary chip looks a lot like the existing song-change toast, which itself has some special-cased suppression rules per Phase 18's Key Decisions). The existing precedent of special-casing suppression rules (skip during Charging/Device, suppress while manually expanded) is reasonable *within* the resolver's model, but is easy to misread as license to bypass the resolver entirely for "simple" cases.

**How to avoid:**
- Every new HUD type — no exceptions, including ones that feel trivial — enqueues through the same `IslandResolver`/`TransientQueue` path as the existing three activities. Suppression rules (e.g., "Focus HUD skips if Charging is active") are expressed as priority/ranking rules *within* the resolver, the same way Phase 18's song-change-toast suppression rules were implemented, not as `if` guards in the view.
- Before implementation, write out the full priority ranking for all activities as one ordered list/table (a single source of truth) — this is cheap to review and catches "wait, what happens when Focus and Calendar-countdown are both live" questions before they become runtime bugs.
- Watch for HUD-specific one-off timers/dismiss-durations proliferating outside `TransientQueue`'s shared duration model (each new HUD invented its own bespoke `DispatchQueue.main.asyncAfter` dismiss timer is a visible warning sign of the pattern breaking down).

**Warning signs:**
- A HUD type has its own local `@State isVisible` toggle set directly from a monitor callback, bypassing the resolver — grep for this pattern during review.
- Two HUDs visibly overlap or flash in sequence when their underlying events fire in the same tick (e.g., plugging in a charger while a calendar countdown is active) — this is the resolver's job to arbitrate; if it happens, something bypassed it.

**Phase to address:**
Ongoing code-review discipline across every HUD-adding phase, not a single dedicated phase — but worth an explicit up-front phase (or a shared design doc) that enumerates the full priority table for all 7+ new HUD types before splitting the work across phases, so no phase invents its own local ordering.

---

### Pitfall 7: Calendar countdown HUD ticking every minute for up to an hour becomes an idle-CPU/wake-up regression if it doesn't follow the project's existing timer-hygiene convention

**What goes wrong:**
A naive implementation drives the countdown off a `Timer`/`DispatchSourceTimer` firing every 60s continuously whenever *any* calendar event exists within the next hour, regardless of whether the countdown HUD is actually visible (e.g., resolver has a higher-priority activity showing, or the panel itself is hidden in fullscreen). Every timer wake is a real, measurable energy cost (Apple's own Energy Efficiency Guide: "any kind of timer must wake the system from its idle state... associated energy cost"), and a naive polling-everywhere pattern is precisely what this project has already deliberately avoided elsewhere (`EqualizerBars` only animates while playing; the Charging/Device activities are event-driven off IOKit/IOBluetooth notifications, not polling).

**Why it happens:**
A per-minute countdown feels like it obviously needs a per-minute timer, and it's easy to wire that timer up at the `CalendarCountdownMonitor`'s init time rather than gating it to "only run while the countdown is actually the thing that could be shown" and "only recompute at the actual minute boundary, not on a fixed-since-launch interval."

**How to avoid:**
- Compute the *next* relevant fire time (next full-minute boundary, or next state transition — event starts in <1hr, event starts, event passed) and schedule exactly one `DispatchSourceTimer`/`Timer` firing at that instant, rescheduling after each fire — not a perpetual 60s repeating timer with a tolerance bolted on as an afterthought.
- Gate the monitor's timer lifecycle to the same on/off conditions the rest of the app already uses: don't run it while there's no calendar event within the lookahead window, and set a tolerance (~10% of interval per Apple's own guidance) to allow timer coalescing.
- Reuse the resolver-visibility gate already used elsewhere (fullscreen suppression, etc.) to decide whether the countdown HUD *can* show — but the underlying EventKit next-event computation can stay cheap/lazy (recomputed on calendar-change notifications, not polled) independent of whether the timer to trigger a re-render needs to run.
- Contrast with Droppy's own Focus-detection polling (0.5s indefinite `DispatchSourceTimer`, Pitfall 2) as a worked example of the anti-pattern to specifically avoid replicating for the calendar countdown.

**Warning signs:**
- Activity Monitor → Energy → "Idle Wake Ups" column shows non-trivial wakeups from Islet with no calendar event actually imminent — the concrete way to verify this in practice, per Apple's own debugging guidance.
- Countdown timer keeps running after the panel enters hidden/fullscreen-suppressed state.

**Phase to address:**
The calendar countdown HUD's own phase — low risk if the existing `EqualizerBars`/event-driven convention is explicitly restated as an acceptance criterion for this feature, not assumed.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|-----------------|-----------------|
| Use `.cgAnnotatedSessionEventTap` because a tutorial shows it | Slightly simpler event decoding | Silently breaks play/pause/next/prev on Tahoe (confirmed regression class) | Never — always use `.cgSessionEventTap` per Pitfall 1 |
| Poll `Assertions.json` on a tight 0.1–0.5s interval "to feel responsive" | Focus HUD appears to react instantly | Needless idle wakeups, battery cost, no real UX benefit since Focus changes are rare human actions | Only acceptable if lookahead is capped and interval is ≥1s with tolerance; never sub-second |
| Bypass `IslandResolver` for a "simple" one-off HUD (e.g., drop-session summary chip) | Faster to ship | Reintroduces the exact scattered-priority-logic bug class Phase 6 was built to eliminate | Never — see Pitfall 6 |
| New material as a fresh `NSViewRepresentable`/wrapper view instead of a modifier on the existing shape | Easier to get the blur "just right" in isolation | Breaks `matchedGeometryEffect` continuity (WR-02-class regression) | Never for the pill/expanded shell; acceptable for genuinely new, non-morphing sub-elements only |
| Ship Sparkle's default update-alert UI unmodified in an LSUIElement app | Zero custom UI work | Conflicts with the app's "never steals focus" design principle; version-dependent focus behavior | Acceptable only as a stopgap for an internal/dev build, not the public release |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|-----------------|-------------------|
| CGEventTap (volume/brightness) | Requesting only Input Monitoring, assuming it's enough to suppress the system HUD | Requires **Accessibility** permission (`.defaultTap`, not `.listenOnly`) to actually consume/suppress the event |
| `~/Library/DoNotDisturb/DB/Assertions.json` (Focus) | Assuming a normal TCC prompt will appear | Full Disk Access has no programmatic prompt — must design an explicit "please grant this manually" onboarding step |
| Sparkle + LSUIElement | Copying an older Sparkle 1.x/early-2.x integration guide | Use current Sparkle 2.x, verify LSUIElement focus behavior against the current CHANGELOG, decide explicitly whether to suppress Sparkle's own alert UI in favor of a custom in-notch Update HUD |
| Sparkle appcast/EdDSA | Forgetting `sparkle:edSignature` on a manually-edited appcast entry, or rotating the EdDSA key and the Developer ID signing identity in the same release | Always run `generate_appcast` (never hand-edit signatures); rotate EdDSA key and Developer ID identity in separate releases, never both at once |
| `IslandResolver` + new HUD types | Wiring a new monitor's callback directly to view-layer `@State` | Every new activity source enqueues through the existing resolver/`TransientQueue` path, no exceptions |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|-----------------|
| Perpetual 60s-repeating countdown timer with no gating | Elevated idle wakeups in Activity Monitor even with no calendar event soon | Schedule one-shot timers to the next actual boundary; gate to "event exists within lookahead" | Immediately measurable, not a scale issue — a single always-on timer is enough to show up in Energy Impact |
| 0.5s (or faster) Focus-state poll running indefinitely | Continuous small CPU/energy draw, worse on battery | ≥1s interval with tolerance, or event-driven if a better signal is ever found | Immediately measurable |
| Blur/material re-rendered on every hover/drag frame inside the `NSPanel` | Frame drops during the collapse/expand spring, visible stutter | Ensure the material modifier isn't forcing a layout-identity change every frame (see Pitfall 4); profile with Instruments' Core Animation/SwiftUI templates during the spring animation specifically | Visible even at small scale — this is a per-frame concern, not a data-scale one |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| CGEventTap callback blindly re-enables itself on `tapDisabledByTimeout`/`tapDisabledByUserInput` without re-checking permission | If Accessibility is revoked mid-session, a naive re-enable loop fights the system and can freeze the WindowServer | Check permission status before re-enabling; stop the interceptor entirely if permission was revoked (Droppy's own fix for this exact bug) |
| Sparkle EdDSA private signing key stored/accessible on the same machine that hosts the appcast/update files | A compromised web host also compromises the ability to sign malicious "updates" | Keep the EdDSA private key off the hosting machine; sign releases locally, upload only the signed artifacts + appcast |
| Full Disk Access requested "just in case" broader than the one file actually needed | Unnecessarily broad permission footprint for a small feature, raises user suspicion and App-notarization-adjacent scrutiny | Request/explain Full Disk Access specifically and only in the context of the Focus feature; make it possible to use the rest of the app fully without granting it |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-------------------|
| Focus Mode feature silently does nothing pre-Full-Disk-Access with no explanation | User thinks the feature is broken/buggy | Explicit first-use explanation + deep link to the System Settings pane, mirroring the project's existing onboarding-flow pattern |
| Sparkle's default update alert steals focus from whatever the user was doing | Breaks the app's core "never interrupts" promise, feels un-Islet | Route update-available through the same in-notch HUD pattern as everything else; only let Sparkle's own UI appear for the actual install/relaunch confirmation step, if at all |
| Volume/brightness suppression silently fails for a USB audio device the app can't control | User's volume keys appear completely dead | Explicit fallback: if Islet can't control the target device, don't consume the key event — let the system handle it and show the system HUD as before |
| Dual-activity secondary bubble flickers/shows stale content during rapid activity changes (e.g., skipping tracks near a countdown boundary) | Feels janky, undermines the "polished, Apple-quality" bar this project holds itself to | Single ordered arbiter pass per Pitfall 5, not two independent resolvers racing |

## "Looks Done But Isn't" Checklist

- [ ] **Volume/Brightness HUD suppression:** Often missing a verified transport-key passthrough test — verify play/pause/next/previous still work system-wide after wiring the tap, specifically on the current macOS version.
- [ ] **Focus Mode HUD:** Often missing the "Full Disk Access denied" path entirely — verify a fresh, ungranted install doesn't crash, spin, or silently poll forever with no user-visible explanation.
- [ ] **Sparkle integration:** Often missing a real end-to-end update-and-relaunch test on an LSUIElement build — verify the app actually restarts correctly with no Dock icon/menu bar app menu assumptions baked into Sparkle's default flow.
- [ ] **Liquid Glass material:** Often missing the full Phase-25-style 7-point on-device UAT — verify the collapsed↔expanded morph specifically, not just static screenshots of each state.
- [ ] **Dual-activity display:** Often missing tests for the *transition* moments (promotion, demotion, simultaneous end) — verify not just "two activities can coexist" but "what happens in the frame where one ends."
- [ ] **New HUD types generally:** Often missing resolver-priority documentation — verify every new HUD's rank is written down in one place, not inferred from scattered `if` conditions.
- [ ] **Calendar countdown HUD:** Often missing idle-CPU verification — verify via Activity Monitor's Idle Wake Ups column with no imminent event, not just "it counts down correctly when I test it."

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|-----------------|-----------------|
| Annotated-tap transport-key breakage shipped to users | LOW | Swap to `.cgSessionEventTap`, ship a patch release — isolated to one file if `VolumeHUDInterceptor` was properly isolated per Pitfall 1 |
| Focus Mode feature rejected/descoped after spike finds Full Disk Access UX unacceptable | LOW–MEDIUM | Drop the feature cleanly since it should already be isolated behind one `FocusModeMonitor` protocol; no other feature should depend on it |
| `matchedGeometryEffect` continuity broken by the material redesign | MEDIUM | Revert the material to a modifier on the existing shape node (same fix pattern as this project would use for WR-02); re-run the Phase-25 UAT checklist |
| Resolver bypassed by a HUD shipped outside `IslandResolver` | MEDIUM–HIGH | Refactor the offending HUD's trigger path into the resolver/`TransientQueue`, re-verify against the full priority table — cost scales with how many other features grew dependent on the bypass in the meantime |
| Dual-activity race causes visible flicker in production | MEDIUM | Collapse to a single ordered arbiter pass if two independent resolver paths were built; add the missing transition-moment tests that would have caught it |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|-------------------|----------------|
| Wrong event-tap variant breaks transport keys | Dedicated OSD-suppression research/spike phase | On-device test of all 4 transport keys + volume/brightness on current macOS, before any HUD UI is built on top |
| Focus Mode has no supported API, needs Full Disk Access | Dedicated Focus-detection research/spike phase | Confirm the Full Disk Access onboarding flow with the user before committing to the feature as scoped; have a documented fallback if rejected |
| Sparkle/LSUIElement focus conflicts | Sparkle integration phase | End-to-end update-and-relaunch test on the actual LSUIElement build, current Sparkle version's CHANGELOG reviewed |
| Material redesign breaks `matchedGeometryEffect` | Liquid Glass material phase | Reuse Phase-25's 7-point on-device UAT checklist as a hard gate |
| Dual-activity races / geometry conflicts | Its own isolated phase, after single-HUD types are proven | Combinatorial test coverage for promotion/demotion/simultaneous-end transitions, not just steady-state coexistence |
| HUD case-explosion bypassing the resolver | Shared design doc/phase enumerating the full priority table before splitting HUD work across phases | Code review checklist: every new activity source enqueues through `IslandResolver`/`TransientQueue`, no direct `@State` wiring |
| Calendar countdown timer hygiene | Calendar countdown HUD phase | Activity Monitor Idle Wake Ups check with no imminent event; one-shot rescheduling verified, not perpetual polling |

## Sources

- **Droppy** (`github.com/1of1Adam/Droppy`, GPL-3.0+Commons-Clause, live source read directly 2026-07-15) — HIGH confidence, this is the actual reference app's shipping implementation:
  - `Droppy/MediaKeyInterceptor.swift` — CGEventTap volume/brightness suppression technique, the Tahoe annotated-tap transport-key regression, Accessibility permission requirement, main-thread-contention double-HUD fix, Caps Lock/TSM crash fix, tap-disabled re-enable-loop safety fix
  - `Droppy/DNDManager.swift` — Focus/DND detection via polling `~/Library/DoNotDisturb/DB/Assertions.json`, Full Disk Access requirement, 0.5s poll interval
  - `Droppy/AutoUpdater.swift`, `DroppyUpdater/main.swift` — Droppy notably built a **custom** updater/helper rather than adopting Sparkle (worth noting as a data point, though this project's STACK.md has already chosen Sparkle)
  - `docs/HUD_IMPLEMENTATION_STANDARDS.md` — HUD sizing/layout/priority conventions (single-HUD-at-a-time priority list, visibility guards)
  - `Droppy/Droppy.entitlements` — confirms no special entitlement beyond sandbox-off is needed for the OSD-suppression technique
- **Sparkle official docs/changelog/issues** (`sparkle-project.org`, `github.com/sparkle-project/Sparkle`) — HIGH confidence on API existence, MEDIUM on exact current-version LSUIElement focus behavior (changed across versions, verify against the CHANGELOG at implementation time):
  - CHANGELOG entries on LSUIElement focus-before-alert behavior
  - Issue #705 (agent app checking updates on behalf of a main bundle), #503 (updater window hidden behind main window)
  - `sparkle-project.org/documentation/eddsa-migration/`, GitHub discussions #2174/#2401/#2597, issue #1521/#1605 — EdDSA signing/key-rotation pitfalls
- **Apple Developer Documentation** — HIGH confidence:
  - `developer.apple.com/documentation/appintents/focus`, INFocusStatusCenter docs and forum thread 682143 — confirms Focus Status API scope is communication-app-oriented, not a general per-mode HUD trigger
  - `developer.apple.com/library/archive/.../power_efficiency_guidelines_osx/Timers.html` — timer coalescing/tolerance/Idle-Wake-Ups guidance
  - `developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents` — Accessibility vs. Input Monitoring distinction
- **SwiftUI Lab** (`swiftui-lab.com/matchedgeometryeffect-part1/`, `part2/`, bug writeup) — MEDIUM-HIGH, well-established reference on `matchedGeometryEffect` id/namespace collision failure modes
- **This project's own `.planning/PROJECT.md`** — HIGH confidence, primary source for WR-01/WR-02 precedent, `IslandResolver`/`TransientQueue` architecture, and the MediaRemote-break precedent that motivates the "isolate behind one protocol" mitigation pattern repeated throughout this document

---
*Pitfalls research for: v1.6 Liquid Glass & System HUD Suite (Islet)*
*Researched: 2026-07-15*
