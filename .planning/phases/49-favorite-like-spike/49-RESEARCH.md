# Phase 49: Favorite/Like — Spike - Research

**Researched:** 2026-07-20
**Domain:** macOS private-API round-trip verification (MediaRemote command send), AppleScript automation reliability, Spotify OAuth PKCE + Web API quota policy, TCC/Automation permission bug reproduction
**Confidence:** MEDIUM-HIGH — one of this spike's four success criteria is now largely pre-answered by direct source inspection (see Key Findings #1 below); the remaining three still require genuine on-device verification, consistent with the milestone-level research's own framing.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Spotify Developer account setup**
- **D-01:** No Spotify Developer app/Client ID exists yet — registering one (developer.spotify.com, setting redirect URI for PKCE) is the spike's own first step, not a pre-existing asset. Budget spike time for this.
- **D-02:** A usable Spotify account (Premium or regular) is available for exercising the real OAuth PKCE round-trip and the real `PUT` Save-Track call — Success Criterion #3 is testable once D-01's app is registered.

**Spotify quota-wall fallback scope**
- **D-03:** If the spike confirms the 5-user Development Mode cap with no realistic Extended Quota path, the accepted fallback for this milestone is: ship Spotify OAuth for a small, manually-approved allowlist — matching REQUIREMENTS.md's FAV-02 as already written. Do NOT descope to Apple-Music-only or switch to bring-your-own-Client-ID as the default plan.
- **D-04:** The 5-user cap is only acceptable if Phase 50's implementation doesn't paint itself into a corner — the design should leave room to later add Extended Quota approval or a bring-your-own-Client-ID option without a rewrite (e.g., don't hardcode a single shared Client ID so deep that swapping the auth source later requires touching every call site). This is a forward-compatibility note for Phase 50's planner, not a Phase 49 deliverable.

**Apple Music test-library coverage**
- **D-05:** Both local-library tracks and streaming-only (not-yet-added) tracks are available on the dev machine — Success Criterion #2's library/streaming-only/play-pause matrix is fully testable on real hardware, no gaps to flag.

**Automation (TCC) bug reproduction depth**
- **D-06:** Reproduce or rule out the Automation-permission prompt bug against Music.app only (the app that ships first via Apple Music write-back) — not a full Music.app + Spotify + idle/backgrounded matrix. Enough to inform Phase 50's FAV-03 error-handling design; Spotify's own unknowns (D-01..D-04) are the bigger risk already covered elsewhere in this spike.

### Claude's Discretion
- Exact spike execution order (Apple Music `loved` testing vs. Spotify OAuth registration vs. TCC repro) — not raised during discussion, sequence for fastest signal on the highest-risk unknown first (Spotify, per research/SUMMARY.md's own risk framing).
- Where the go/no-go decision gets documented (dedicated findings doc vs. Phase 50's CONTEXT.md decisions) — follow this project's existing spike/sketch wrap-up convention if applicable at planning time.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope (spike execution readiness and scope decisions for the already-scoped Favorite/Like unknowns).

Reviewed-but-not-folded todos (unrelated to this phase): Calendar month-grid polish, Quick Action disabled-state controller gate, Island click-through disappearing bug.
</user_constraints>

## Summary

This spike has four success criteria, but direct inspection of the project's *actual* vendored dependency (not the milestone research's cited one) already resolves half of Success Criterion #1 before any on-device test runs. The milestone-level `PITFALLS.md` (Pitfall 1) states the `mediaremote-adapter` command table has "no like/love/favorite/rate command," citing `ungive/mediaremote-adapter`. But Islet's actual `Package.resolved` pins `ejbills/mediaremote-adapter` (revision `cf30c4f1af29b5829d859f088f8dbdf12611a046`) — a maintained fork, not the same codebase — and its `MediaController.swift` (confirmed by reading the resolved SPM checkout directly) exposes `likeTrack()`, `banTrack()`, `addToWishList()`, `removeFromWishList()`, which route through `MediaRemoteAdapter.m` to real private `MRMediaRemoteSendCommand()` calls with genuine command IDs (`kMRLikeTrack = 0x6A`, etc., defined in the vendored `MediaRemote.h`). **The wrapper genuinely can send a like command — this part of Success Criterion #1 is answered YES at HIGH confidence without touching hardware.** What still needs a real on-device test is whether Music.app/Spotify.app actually *honor* that private command end-to-end (does the heart in Music.app / Spotify's Liked Songs actually update). Separately, the streamed `TrackInfo.Payload`/`MediaRemoteAdapterKeys.h` schema has **no** liked/rating/wishlist read-state field at all — Success Criterion #1's second half ("does the payload ever report a favorite read-state") is answered NO by the same source read, not merely "needs testing."

The other three success criteria remain genuinely unverified and must be spiked as planned. Spotify's policy wall is confirmed at HIGH confidence directly from Spotify's own docs (fetched today): Development Mode caps an app at 5 authenticated users, and Extended Quota Mode as of May 2025 requires an *organization* (not an individual), a minimum of 250,000 MAU, and a launched commercial service — there is no solo-developer/hobby exception documented anywhere. This makes D-03's "accept the 5-user cap" fallback essentially a foregone conclusion rather than a 50/50 spike outcome; the actual spike work for Success Criterion #3 is exercising the mechanical PKCE + `PUT /me/library` round-trip, not debating whether Extended Quota is realistic. Apple Music's `current track` bug is corroborated today directly from the two cited Apple Developer Forums threads: the exact error is `-1728` ("Can't get name of current track"), filed as `FB19908171`, reproducible with `tell application "Music" to get name of current track` against a streaming (not-yet-in-library) track. This is a *different* error number from the Automation/TCC denial (`-1743`, `errAEEventNotPermitted`) — the spike's error-handling design must distinguish these two failure modes explicitly, and Success Criterion #2 (current-track reliability) can be sanity-checked via plain `osascript` from Terminal since it is unrelated to which app's Automation permission is granted. Success Criterion #4 (the TCC prompt-reliability bug) genuinely cannot be Terminal-tested the same way — TCC grants are per-requesting-app, so the prompt must be triggered from Islet.app's own compiled, code-signed binary, not from `osascript` run in Terminal (which likely already has broad Automation permission on this dev machine). A forum report today also states `tccutil reset AppleEvents <bundle-id>` was tried and had **no effect** as a workaround — so a full repro (multi-day app idle) may not be achievable within a single spike session; plan to build the recovery-path UX defensively regardless of whether a live repro succeeds.

One concrete blocker predates any of the four success criteria: Islet's current `Islet.entitlements` and Xcode build settings have **neither** `NSAppleEventsUsageDescription` (Info.plist) **nor** the `com.apple.security.automation.apple-events` entitlement, and `ENABLE_HARDENED_RUNTIME = YES` is already set. Without both additions, any `NSAppleScript`/`osascript` call from Islet.app itself will very likely fail outright before any TCC prompt or `-1728`/`-1743` distinction is even reachable. This is Step 0 of the spike, not an incidental detail.

**Primary recommendation:** Treat Success Criterion #1 as already substantiated by code (HIGH confidence, cite the exact revision) and spend on-device time confirming *effect*, not *existence*, of the like command; spend the bulk of spike time on Success Criteria #2–#4, starting with the entitlements/Info.plist prerequisite, then Spotify's mechanical OAuth+PUT round-trip (policy question is already settled), then Apple Music's `current track` matrix, then the TCC-bug repro attempt scoped realistically (attempt, don't block the phase on forcing a multi-day-idle repro).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| MediaRemote like/ban/wishlist command send (Success Criterion #1) | Backend/System Glue (`NowPlayingMonitor`'s existing MediaController bridge) | — | Already the ONLY file that imports MediaRemoteAdapter per CLAUDE.md mandate; the spike's throwaway hook belongs in/near this same isolation boundary, not a new seam |
| Apple Music `loved`/`current track` AppleScript (Success Criterion #2) | Backend/System Glue (new `NSAppleScript` call, off-main) | — | Distinct write mechanism from MediaRemote (no scripting bridge overlap); per STACK.md, isolated behind its own small protocol mirroring `NowPlayingMonitor`'s pattern |
| Spotify OAuth PKCE + `PUT /me/library` (Success Criterion #3) | Backend/System Glue (network + `ASWebAuthenticationSession` in production; a standalone shell/curl harness for the spike itself, see Code Examples) | — | External network+auth concern, no UI this phase — the spike round-trip does not need to touch the app at all (see Pattern 2) |
| Automation/TCC permission-prompt reproduction (Success Criterion #4) | OS-level (System Settings → Privacy & Security → Automation) | Backend/System Glue (must be triggered from Islet.app's own binary, not Terminal) | TCC grants are scoped per requesting-app bundle identity; only Islet.app's own compiled binary can produce a representative test of what a real user will experience |
| Go/no-go scope decision recording | Documentation (spike wrap-up doc / SUMMARY.md, per this project's Phase 22 precedent) | — | No runtime tier — a planning artifact, not code |

## Project Constraints (from CLAUDE.md)

From `./CLAUDE.md` (project root, GSD-managed sections):

- **"Isolate all now-playing code behind one Swift protocol/service so swapping the implementation is a one-file change"** — any spike hook into `MediaController.likeTrack()` should live at/near `NowPlayingMonitor.swift`, the codebase's own designated single seam, not a new parallel bridge.
- **App sandboxing is explicitly rejected** ("Incompatible with the MediaRemote bridge... Ship un-sandboxed, hardened-runtime, notarized") — this is favorable for Automation/Apple Events too (sandboxed apps cannot send Apple Events via `NSAppleScript` at all, per Apple DTS guidance found during this research); Islet's existing unsandboxed posture is a prerequisite this spike can rely on, not something it needs to re-litigate.
- **Hardened runtime is already `YES`** (confirmed directly in `project.pbxproj`) — this DOES require the `com.apple.security.automation.apple-events` entitlement for Apple Events sending; currently absent (see Common Pitfalls, Pitfall C).
- **"First-time programmer... avoid unnecessary complexity"** — favors the leanest possible spike harness (Terminal `osascript` / shell `curl` scripts over new Swift UI or new Xcode targets) wherever a criterion doesn't strictly require running inside Islet.app's own binary.
- **Direct + notarized distribution only, no App Store** — irrelevant tension-wise for Spotify's Web API/OAuth (no App Store review gates that), but confirms no App-Store-specific redirect-URI or entitlement rules apply.

## Standard Stack

No new dependencies — this spike deliberately produces no production code changes (per CONTEXT.md, "spike produces no code changes to `NotchWindowController`/`NotchPillView`"). Everything needed ships with the macOS SDK, or is already resolved via SPM.

### Core (already present / already resolved)
| Library | Version (verified) | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `ejbills/mediaremote-adapter` | pinned `cf30c4f1af29b5829d859f088f8dbdf12611a046` [VERIFIED: Package.resolved] | Now Playing bridge; ALSO exposes `likeTrack()`/`banTrack()`/`addToWishList()`/`removeFromWishList()` | Already the project's Now Playing dependency (see `NowPlayingMonitor.swift`); no new install needed — this spike only needs to *call* an already-present method |
| `NSAppleScript` (Foundation) | ships with macOS | Apple Music `loved`/`current track` read-write | No dependency; same "tiny native surface" precedent as IOKit/IOBluetooth already used in this codebase |
| `AuthenticationServices` / manual PKCE via shell (`openssl`, `curl`) | ships with macOS | Spotify OAuth PKCE round-trip | For the spike specifically: recommend the zero-app-code shell-script approach (see Code Examples) since no UI exists yet this phase; `ASWebAuthenticationSession` is the STACK.md-recommended production mechanism for Phase 50, not required for this spike's verification |

### Supporting (spike-only, throwaway)
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `osascript` (Terminal) | Fast sanity-check of Apple Music's `current track`/`loved` AppleScript bug (Success Criterion #2, Pitfall 2 sub-question) | Valid ONLY for the `current track` reliability question — NOT valid for the TCC/Automation prompt-bug question (Success Criterion #4), because TCC grants are scoped to the calling app's bundle identity, and Terminal.app is a different requester than Islet.app |
| A throwaway hook in/near `NowPlayingMonitor.swift` (e.g., a temporary debug keyboard shortcut calling `controller.likeTrack()`, NSLog-marked) | Exercise the real `MRMediaRemoteSendCommand(kMRLikeTrack, ...)` send from Islet's own process against a real playing track | Mirrors this project's own Phase 22 precedent (throwaway `NSDraggingDestination` spike scaffold, NSLog-marked, committed, later replaced) |
| Minimal shell script (PKCE code_verifier/code_challenge generation + `open` + `curl`) | Spotify OAuth PKCE + `PUT /me/library` round-trip, entirely outside the app | Leanest path to a genuine, spike-scoped answer for Success Criterion #3 without writing any Swift/Xcode code this phase |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Shell-script PKCE harness for the spike | In-app `ASWebAuthenticationSession` throwaway button | Closer to Phase 50's eventual production shape, but requires new Swift/Xcode code + a `CFBundleURLTypes` Info.plist entry this phase explicitly says isn't needed yet ("No UI is built this phase") |
| Terminal `osascript` for Success Criterion #2's first pass | A throwaway AppleScript call inside Islet.app itself | Terminal is faster to iterate and correctly isolates the *current track* bug (an app-internal Music.app scripting issue, not TCC-scoped) — but Success Criterion #4 (TCC) still requires the in-app path regardless |

**Installation:** None — no `npm install`/SPM package additions this phase. If entitlements/Info.plist changes are needed (see Pitfall C), those are Xcode project-setting edits, not package installs.

**Version verification:** `ejbills/mediaremote-adapter` pin confirmed directly via `Islet.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` — `"location": "https://github.com/ejbills/mediaremote-adapter", "revision": "cf30c4f1af29b5829d859f088f8dbdf12611a046"`. This is the actual code shipping in Islet.app today, distinct from `ungive/mediaremote-adapter` (the upstream project this fork is based on, and the repo the milestone research's Pitfall 1 appears to have investigated instead).

## Package Legitimacy Audit

**Not applicable this phase.** No new external packages are installed — the spike uses only Apple system frameworks (`Foundation`/`NSAppleScript`, optionally `AuthenticationServices`) and the already-resolved, already-embedded `ejbills/mediaremote-adapter` SPM dependency (no version bump, no new pin). If the go/no-go decision leads to any new dependency being proposed for Phase 50 (none currently anticipated — Spotify's Web API needs no SDK, only `URLSession`/`ASWebAuthenticationSession`), that phase's own research must run the full legitimacy gate at that time.

## Architecture Patterns

### System Architecture Diagram

```
                         ┌─────────────────────────────┐
                         │   Islet.app (spike-only      │
                         │   throwaway instrumentation) │
                         └──────────────┬───────────────┘
                                         │
        ┌────────────────────┬──────────┴───────────┬────────────────────┐
        │                    │                       │                    │
        ▼                    ▼                       ▼                    ▼
┌───────────────┐   ┌─────────────────┐    ┌──────────────────┐  ┌──────────────────┐
│ MediaController│   │ NSAppleScript    │    │ osascript (Term.)│  │ Shell script      │
│ .likeTrack()   │   │ (from Islet.app  │    │ 'current track'  │  │ (PKCE gen + open  │
│ (SC #1)        │   │  binary, SC #4)  │    │ sanity check      │  │  + curl, SC #3)   │
└───────┬────────┘   └────────┬─────────┘    │ (SC #2, no TCC    │  └────────┬─────────┘
        │                     │              │  identity issue)  │           │
        ▼                     ▼              └──────────────────┘           ▼
┌───────────────┐   ┌─────────────────┐                            ┌──────────────────┐
│ Private        │   │ Apple Events /  │                            │ accounts.spotify  │
│ MRMediaRemote  │   │ TCC subsystem   │                            │ .com  ->  api      │
│ SendCommand    │   │ (permission     │                            │ .spotify.com       │
│ (kMRLikeTrack) │   │  prompt, or the │                            │ (real OAuth PKCE   │
└───────┬────────┘   │  documented     │                            │  + PUT /me/library)│
        │            │  no-prompt bug) │                            └──────────────────┘
        ▼            └────────┬────────┘
┌───────────────┐             ▼
│ Music.app /    │   ┌─────────────────┐
│ Spotify.app    │   │ Music.app       │
│ (does the      │   │ ("loved" write, │
│  heart/like    │   │  "current       │
│  actually      │   │  track" read —  │
│  update?)      │   │  -1728 bug)     │
└───────────────┘   └─────────────────┘

Output of all four paths -> ONE documented go/no-go decision
(scope: ship Spotify OAuth allowlist / bring-your-own-Client-ID / Apple-Music-only)
```

### Recommended Project Structure

No new files required for the spike itself if the Terminal/shell-script paths are used for Success Criteria #2 (first pass) and #3. For Success Criteria #1 and #4 (which must run from Islet's own binary):

```
Islet/Notch/
├── NowPlayingMonitor.swift   # (TEMP MODIFY) — throwaway likeTrack() hook, NSLog-marked, removed/replaced by Phase 50
Islet/Islet.entitlements       # (MODIFY) — add com.apple.security.automation.apple-events
Islet.xcodeproj/project.pbxproj  # (MODIFY) — add INFOPLIST_KEY_NSAppleEventsUsageDescription
```

### Pattern 1: Throwaway spike scaffolding, committed and NSLog-marked (this project's own established convention)

**What:** Add the minimum instrumentation needed to exercise a real code path, mark it unmistakably as spike scaffolding (e.g., `NSLog("SPIKE ...")`), commit it, and record the on-device verdict in the plan's own SUMMARY.md rather than a separate findings doc.
**When to use:** For Success Criteria #1 and #4, which must run inside Islet.app's own process (the `likeTrack()` send needs the app's own MediaController instance already wired up in `NowPlayingMonitor`; the TCC prompt needs Islet's own bundle identity).
**Example (this project's own precedent, Phase 22):**
```swift
// Source: Islet/Notch/NotchPanel.swift, Phase 22 Plan 01 (22-01-SUMMARY.md)
// "4 throwaway, NSLog-marked NSDraggingDestination stub methods" — same discipline
// applies here: a temporary debug hook, not production wiring.
```

### Pattern 2: Out-of-app verification for network/OAuth flows that don't need the app's UI yet

**What:** Spotify's OAuth PKCE flow and `PUT /me/library` call can be fully exercised with a standalone shell script (generate `code_verifier`/`code_challenge`, open `/authorize` in the default browser, paste the `code` param from the redirect, `curl` the token exchange, `curl` the `PUT`) — no Xcode project changes at all.
**When to use:** Success Criterion #3. This phase has no UI and CONTEXT.md is explicit that none should be built — writing a throwaway `ASWebAuthenticationSession` button would be extra unrequested surface for a question a shell script answers just as definitively.
**Example:** See Code Examples section below (full script).

### Anti-Patterns to Avoid
- **Testing the TCC/Automation prompt bug via `osascript` in Terminal:** Terminal.app is very likely already Automation-authorized on this dev machine from unrelated prior use — a "successful" Terminal-triggered AppleScript call proves nothing about Islet.app's own first-ever automation attempt. Must trigger from Islet's own compiled, code-signed binary.
- **Building a full `ASWebAuthenticationSession` + Keychain harness for this phase:** Over-scopes a spike whose CONTEXT.md explicitly says "No UI is built this phase" — the shell-script round-trip answers Success Criterion #3 without it; save the production `ASWebAuthenticationSession` wiring for Phase 50.
- **Assuming the milestone research's Pitfall 1 premise ("no like command exists") without re-checking the actual pinned dependency:** As shown above, the actual `ejbills/mediaremote-adapter` fork Islet uses does have `likeTrack()`/`banTrack()`/wishlist commands — always verify against `Package.resolved`'s actual `location`/`revision`, not a repo name recalled from memory or a prior research pass.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PKCE `code_verifier`/`code_challenge` generation | A custom random-string + SHA256 implementation from scratch in a new Swift file | The shell-script `openssl rand`/`shasum -a 256` one-liners (see Code Examples), or `AuthenticationServices`' own PKCE support in Phase 50 | The spike doesn't need production-grade code; a 5-line shell snippet using `openssl`/`shasum` is both correct and faster to iterate than compiling a Swift harness for a throwaway test |
| Determining "is the Spotify quota wall real" | A second research pass or asking on forums | Spotify's own Developer Dashboard + the officially fetched criteria in this doc (already HIGH confidence) | Already answered directly from Spotify's official docs today — the spike's job is the mechanical `PUT` round-trip, not re-litigating the policy question |
| Detecting whether an AppleScript failure is the TCC-denial (-1743) vs. the `current track` bug (-1728) | A single generic `catch { showError() }` | Explicit `if error.number == -1728 { ... } else if error.number == -1743 { ... }` branching, matching Apple's own DTS-recommended try/catch pattern | These are two structurally different failure modes with two different recovery UX needs (Pitfall 2 vs Pitfall 3) — collapsing them loses the information FAV-03 needs |

**Key insight:** This spike's highest-leverage move is reading source before running anything — the `mediaremote-adapter` command-table question was fully answerable from a `Package.resolved` + SPM-checkout read, at zero on-device time cost, and it materially changes what the remaining on-device time should focus on (effect, not existence).

## Common Pitfalls

### Pitfall 1 (CORRECTS milestone PITFALLS.md Pitfall 1's premise): The actual vendored `mediaremote-adapter` DOES have like/ban/wishlist commands — verify effect, not existence

**What goes wrong:** Trusting the milestone-level research's claim that "the adapter's own documented command table... has no like/love/favorite/rate command" without re-checking which repository is actually pinned. That claim was researched against `ungive/mediaremote-adapter`; Islet's `Package.resolved` pins `ejbills/mediaremote-adapter` at revision `cf30c4f`, a maintained fork that DOES expose `likeTrack()`/`banTrack()`/`addToWishList()`/`removeFromWishList()`, wired to real `MRMediaRemoteSendCommand(kMRLikeTrack, nil)` calls (command IDs `0x6A`–`0x6D` in the vendored `MediaRemote.h`).
**Why it happens:** Two same-named-but-different GitHub projects (`ungive/mediaremote-adapter` is the original; `ejbills/mediaremote-adapter` is a Swift-wrapper fork with its own divergent command set) are easy to conflate, especially since CLAUDE.md's own Stack section credits both names in the same breath ("`ungive/mediaremote-adapter`, with the Swift wrapper `ejbills/mediaremote-adapter`").
**How to avoid:** For Success Criterion #1, do NOT spend spike time re-discovering whether the command exists (it does, confirmed by source read). Spend it confirming Music.app's/Spotify.app's heart-icon or Liked-Songs state actually flips after the call — that is the genuinely unknown half.
**Warning signs:** A plan that budgets a "does the wrapper support this at all" investigation task for Success Criterion #1 is re-doing work this research already completed; redirect that budget to an on-device "does it work" checkpoint instead.
**Phase to address:** This phase (spike) — but scoped to the effect question only.

---

### Pitfall 2 (confirms milestone PITFALLS.md Pitfall 2, with exact error details): `current track` fails with error -1728, filed as FB19908171

**What goes wrong:** `tell application "Music" to get name of current track` (and `loved of current track`) throws `error "Music got an error: Can't get name of current track." number -1728` specifically for tracks not yet in the local library — confirmed today via Apple Developer Forums thread 798267 and separately corroborated by discussions.apple.com thread 256158179 ("Tahoe broke my AppleScript for Music"). Apple DTS's own recommended workaround is wrapping every access in `try`/`on error`, not attempting to fix the underlying bridge.
**Why it happens:** `current track` was designed around iTunes-era local libraries; Apple Music's streaming catalog only partially maps onto that model and Apple has not kept the AppleScript bridge in sync — described in the forum thread as unintentional, not a deliberate API change (auto-played/Listen-Now tracks fail even more consistently than deliberately opened catalog tracks).
**How to avoid:** Test explicitly across: (a) a library track, (b) a streaming-only "For You"/Listen Now track, (c) both play and pause states — matching D-05's already-confirmed hardware availability. This specific sub-question can be checked fast via plain Terminal `osascript` (no TCC-identity concern, since the bug lives inside Music.app's own scripting bridge, not in Islet's permission grant).
**Warning signs:** A "works when I tested it" result from only a library track is not sufficient — the bimodal failure is specifically about streaming-only tracks.
**Phase to address:** This phase (spike), Success Criterion #2.

---

### Pitfall 3 (confirms milestone PITFALLS.md Pitfall 3, with a critical Terminal-vs-app-identity nuance): The TCC/Automation prompt bug cannot be validated from Terminal

**What goes wrong:** Testing "does the Automation permission prompt appear reliably" by running `osascript` commands in Terminal.app proves nothing about Islet.app's own behavior — TCC (Transparency, Consent, and Control) grants are scoped per requesting-app bundle identity, and Terminal.app very likely already has broad Automation permissions on this dev machine from unrelated prior use. A forum report (Apple Developer Forums thread 792157, fetched today) also states that `tccutil reset AppleEvents <bundle-id>` was tried by an affected developer and had **no effect** as a recovery workaround, and that the affected target app can silently fail to even appear in System Settings → Privacy & Security → Automation for the user to grant permission manually.
**Why it happens:** This is a real, filed macOS TCC subsystem bug, apparently tied to a first-launch/idle-state race in how TCC discovers the automation target — not something Terminal-based testing can substitute for, since Terminal's own TCC grant is a separate, already-established identity.
**How to avoid:** Trigger the Apple Event from Islet.app's own compiled, code-signed binary (a throwaway debug hook per Pattern 1) — not from Terminal. Given the bug's reported trigger condition is "the target app hasn't been used in a while" (days/weeks of idle time before Islet's first automation attempt), a full live repro may not be achievable inside a single spike session; if it can't be forced, document that honestly as an open question rather than reporting a false "not reproducible" verdict, and design FAV-03's recovery UX (relaunch-target-app affordance, `-1743`-specific messaging) regardless of whether a live repro succeeds this phase.
**Warning signs:** A spike verdict of "TCC bug not reproducible" based only on Terminal-triggered tests, or based only on freshly-launched-app tests (the bug is specifically idle-state-dependent).
**Phase to address:** This phase (spike), Success Criterion #4 — with an honest "attempted, could not force within the spike window" outcome accepted as valid if idle-time reproduction genuinely isn't practical.

---

### Pitfall C: Islet currently has NEITHER the entitlement NOR the Info.plist key needed to send Apple Events at all

**What goes wrong:** `Islet.entitlements` (read directly) contains `com.apple.security.cs.disable-library-validation`, `com.apple.developer.weatherkit`, calendar/location entitlements, and `com.apple.developer.usernotifications.communication` — but NOT `com.apple.security.automation.apple-events`. `project.pbxproj`'s `INFOPLIST_KEY_*` entries (read directly) list Bluetooth/Calendar/Focus/Input-Monitoring/Location/Reminders usage descriptions — but NOT `NSAppleEventsUsageDescription`. `ENABLE_HARDENED_RUNTIME = YES` is already set for both Debug and Release configs. Under hardened runtime, sending Apple Events to another app without the entitlement will very likely fail immediately (before any TCC prompt or `-1728`/`-1743` distinction is even reachable), making Success Criteria #2 and #4 impossible to test from Islet's own binary until this is fixed.
**Why it happens:** No prior phase has needed Apple Events — this is the first phase to add Automation as a capability.
**How to avoid:** Add both as Step 0 of the spike, before any AppleScript testing from Islet.app itself: (1) `com.apple.security.automation.apple-events` to `Islet.entitlements`; (2) `INFOPLIST_KEY_NSAppleEventsUsageDescription` (a user-facing permission string, matching the existing German-language convention used for the other `INFOPLIST_KEY_*` usage strings in this project) to both Debug and Release build settings.
**Warning signs:** Any AppleScript call from Islet.app itself failing with a generic, non-`-1728`/non-`-1743` error before a permission prompt is even seen — check the entitlement/Info.plist state first, don't assume it's the TCC bug.
**Phase to address:** This phase (spike), as a prerequisite task before Success Criteria #2 and #4's in-app testing.

---

### Pitfall 4 (unchanged from milestone research, HIGH confidence, verified today): Spotify's 5-user cap and Extended Quota exclusion are real, official, and leave no solo-developer path

**What goes wrong:** Assuming Extended Quota Mode is a realistic target for a solo-developer hobby product. Fetched directly from Spotify's own documentation today: Development Mode caps an app at "Up to 5 authenticated Spotify users," and Extended Quota Mode (as of May 15, 2025) requires: an organization (explicitly "not individuals"), a minimum of 250,000 MAU, an established registered business, an active launched service, and market/commercial-viability review — a six-week review process, submitted via a company email. No solo-developer/hobby exception is documented anywhere in the current criteria.
**Why it happens:** Spotify's policy tightened in 2025 specifically to exclude exactly this category of app (a solo-developer, direct-distributed, paid hobby product).
**How to avoid:** Treat D-03's "accept the 5-user cap, ship a small manually-approved allowlist" as the expected outcome, not a coin-flip pending spike results — the spike's real remaining work for Success Criterion #3 is the mechanical PKCE + `PUT /me/library` round-trip (does it actually work end-to-end for one real account), not the policy research (already settled).
**Warning signs:** A plan that budgets significant time to "determine whether Extended Quota is obtainable" — that question is already answered; don't re-research it, verify only that nothing has changed since this fetch (2026-07-20).
**Phase to address:** This phase (spike), Success Criterion #3 — mechanical verification only, policy question pre-answered.

## Code Examples

### Success Criterion #1: Throwaway `likeTrack()` hook (mirrors Phase 22's NSLog-marked scaffold convention)

```swift
// Source: verified against the actual vendored MediaController.swift
// (checkouts/mediaremote-adapter/Sources/MediaRemoteAdapter/MediaController.swift, line 338)
// TEMP — spike scaffold only, remove/replace once go/no-go is recorded.
// Suggested wiring point: NowPlayingMonitor.swift, mirroring togglePlayPause()'s
// existing pass-through pattern (line 94 of the current file).
func spikeLikeCurrentTrack() {
    NSLog("SPIKE likeTrack() sending kMRLikeTrack")
    controller.likeTrack()   // -> MRMediaRemoteSendCommand(kMRLikeTrack, nil)
}
```
Wire this to a temporary debug keyboard shortcut or menu item; play a track in Music.app/Spotify, trigger it, and visually confirm (heart icon in Music.app, "Liked Songs" in Spotify) whether the private command was honored.

### Success Criterion #2: Fast Terminal sanity-check of the `current track` bug (no TCC-identity concern)

```bash
# Library track / streaming-only track / play / pause — run once per combination.
osascript -e 'tell application "Music" to get name of current track'
osascript -e 'tell application "Music" to get loved of current track'
osascript -e 'tell application "Music" to set loved of current track to true'
```
Expected per PITFALLS.md/this research: succeeds for library tracks, fails with
`error "Music got an error: Can't get name of current track." (-1728)` for streaming-only tracks.

### Success Criterion #3: Zero-app-code Spotify OAuth PKCE + save-track round-trip

```bash
#!/bin/bash
# Source: Spotify for Developers — Authorization Code with PKCE flow docs
# (developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow, fetched 2026-07-20)
# and February 2026 migration guide for the PUT /me/library shape.
CLIENT_ID="<from developer.spotify.com/dashboard, D-01>"
REDIRECT_URI="http://127.0.0.1:8888/callback"   # loopback — bare "localhost" is rejected

VERIFIER=$(openssl rand -base64 96 | tr -d '\n=+/' | cut -c1-64)
CHALLENGE=$(printf '%s' "$VERIFIER" | openssl dgst -sha256 -binary | openssl base64 | tr '+/' '-_' | tr -d '=')

AUTH_URL="https://accounts.spotify.com/authorize?client_id=${CLIENT_ID}&response_type=code&redirect_uri=${REDIRECT_URI}&code_challenge_method=S256&code_challenge=${CHALLENGE}&scope=user-library-modify%20user-library-read"
open "$AUTH_URL"   # complete login in the browser, copy the ?code=... from the redirected URL

read -p "Paste the 'code' param from the redirect URL: " AUTH_CODE

TOKEN_RESPONSE=$(curl -s -X POST https://accounts.spotify.com/api/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d grant_type=authorization_code \
  -d code="$AUTH_CODE" \
  -d redirect_uri="$REDIRECT_URI" \
  -d client_id="$CLIENT_ID" \
  -d code_verifier="$VERIFIER")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c 'import sys,json; print(json.load(sys.stdin)["access_token"])')

# Real PUT /me/library save-track call (post Feb-2026 migration shape — URI-based, not ID-based)
curl -s -X PUT https://api.spotify.com/v1/me/library \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"uris": ["spotify:track:<a real currently-playing track id>"]}'
```
This exercises the real PKCE flow and the real Feb-2026 `PUT /me/library` shape end-to-end with zero Xcode/Swift code — appropriate for a phase with no UI.

### Success Criterion #4: TCC-representative trigger (must run from Islet.app, not Terminal)

```swift
// TEMP — spike scaffold only. Wire to a debug menu item so it runs inside
// Islet.app's own compiled, code-signed process (TCC grants are per-bundle-ID).
func spikeTriggerAutomationPrompt() {
    let script = NSAppleScript(source: "tell application \"Music\" to get name of current track")
    var errorDict: NSDictionary?
    let result = script?.executeAndReturnError(&errorDict)
    if let errorDict {
        let number = errorDict[NSAppleScript.errorNumber] as? Int
        NSLog("SPIKE AppleScript error number=\(number ?? -1) dict=\(errorDict)")
        // -1743 (errAEEventNotPermitted) = TCC denial/never-prompted (Pitfall 3)
        // -1728 ("can't get X of Y")     = current-track bug (Pitfall 2), NOT a TCC issue
    } else {
        NSLog("SPIKE AppleScript succeeded: \(result?.stringValue ?? "nil")")
    }
}
```
Requires Pitfall C's entitlement + Info.plist additions first, or this will fail before reaching either error path.

## State of the Art

| Old Approach (milestone research, 2026-07-19) | Current Finding (this research, 2026-07-20, code-verified) | When Changed | Impact |
|--------------|------------------|-------------|--------|
| "`mediaremote-adapter`'s own documented command table... has no like/love/favorite/rate command" (PITFALLS.md Pitfall 1) | The actual pinned `ejbills/mediaremote-adapter` fork (rev `cf30c4f`) DOES have `likeTrack()`/`banTrack()`/`addToWishList()`/`removeFromWishList()`, routed to real `MRMediaRemoteSendCommand` calls | Discovered today via direct SPM-checkout source read, not a version change — the milestone research appears to have investigated `ungive/mediaremote-adapter` (the upstream project) rather than the actually-pinned `ejbills` fork | Success Criterion #1's "can it send a command" half no longer needs on-device discovery — only "does it work" needs verification |
| "Whether the streamed MediaRemote payload ever reports a rating/favorite read-state" (open question, SUMMARY.md) | Confirmed NO at the wrapper level — `TrackInfo.Payload`/`MediaRemoteAdapterKeys.h` has no such field in the current schema | Same source read | The star button cannot use the streamed payload for its initial "already liked" state via this wrapper as-is; must use a separate read path (Music.app AppleScript `loved of current track` for Apple Music, `GET /me/library/contains` for Spotify) — already what STACK.md recommended, now confirmed necessary rather than optional |
| "Confirm current quota-mode/Extended-Access criteria directly on the Spotify Developer Dashboard" (Success Criterion #3, open question) | Confirmed via official Spotify docs fetched today: 5-user Development Mode cap, Extended Quota requires org + 250k MAU + launched business, no individual/hobby path | Policy effective since 2025-05-15, re-confirmed unchanged as of 2026-07-20 | D-03's fallback scope is now a near-certain outcome, not a genuine unknown — spike time should shift to the mechanical round-trip |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `NSAppleEventsUsageDescription` + `com.apple.security.automation.apple-events` together are sufficient for Islet's hardened-runtime build to send Apple Events (no additional per-target-app `SFAppleScriptTargetApplication`-style declaration needed) | Pitfall C, Project Constraints | If an additional declaration is actually required on the current macOS/Xcode toolchain, Step 0 of the spike will need a second iteration — low cost to discover, but budget a few extra minutes rather than assuming one-shot success |
| A2 | The `MRMediaRemoteSendCommand(kMRLikeTrack, nil)` call, once it reaches Music.app/Spotify.app, behaves the same as the app's own native "like" UI action (updates the same underlying state) | Pitfall 1 (corrected), Summary | If it's a no-op or only partially wired on the receiving app's side, Success Criterion #1 could still fail even though the "can it send a command" question is answered — this is exactly why the spike still needs the on-device effect check |
| A3 | No additional per-app `NSAppleEventsUsageDescription` dictionary entries (Music vs. Spotify individually) are required beyond the single general Info.plist string, matching STACK.md's existing recommendation | Standard Stack, Code Examples | If per-target usage strings are required on the current macOS version, the entitlement/Info.plist step needs a second pass — same low-cost discovery as A1 |

**If this table is empty:** N/A — see entries above.

## Open Questions (RESOLVED)

1. **Does `MRMediaRemoteSendCommand(kMRLikeTrack, nil)` actually update Music.app's/Spotify.app's own liked state, or does the receiving app ignore/partially-honor the private command?**
   - What we know: The command genuinely sends (code-verified, HIGH confidence); command IDs `0x6A`-`0x6D` are defined in the vendored `MediaRemote.h`.
   - What's unclear: Whether Music.app/Spotify.app's current builds actually act on it — no forum/doc evidence either way was found this session (a narrower, more specific search than this research's time budget allowed for).
   - Recommendation: This is squarely what Success Criterion #1's on-device test must answer — treat it as the spike's single most information-dense test.
   - **Resolution:** Answered by Plan 49-01 Task 3's on-device checkpoint — the DEBUG `spikeLikeCurrentTrack()` hook and the human-verify verdict recorded in `49-01-SUMMARY.md`.

2. **Is the Automation/TCC prompt-reliability bug (Success Criterion #4) reproducible within a realistic spike time window at all?**
   - What we know: The documented trigger is extended idle time (days/weeks) of the target app before Islet's first automation attempt; a reported `tccutil reset AppleEvents` workaround did NOT work for at least one affected developer.
   - What's unclear: Whether a shorter artificial trigger exists (e.g., force-quitting Music.app for a few hours, or a fresh reinstall of Islet.app to reset its own TCC state) that reliably reproduces the same failure mode faster.
   - Recommendation: Attempt the fastest available proxy (fresh Islet.app build + a Music.app that hasn't been foregrounded recently) first; if it doesn't reproduce, honestly record "not reproduced within spike window" rather than either forcing a multi-day wait or falsely claiming ruled-out.
   - **Resolution:** Answered by Plan 49-01 Task 3's on-device checkpoint — the DEBUG `spikeTriggerAutomationPrompt()` hook and the TCC-bug verdict (reproduced / ruled-out / not-reproduced-this-session) recorded in `49-01-SUMMARY.md`.

3. **Does Music.app's `loved` write actually round-trip correctly when `current track` itself is inaccessible (the `-1728` case) — is there a viable identifier-based fallback (persistent ID / library-playlist lookup) worth spiking now, or is it out of scope for this phase?**
   - What we know: PITFALLS.md Pitfall 2 suggests a title/artist-based library lookup as a fallback, explicitly flagged as fragile (duplicate titles, remasters).
   - What's unclear: Whether this fallback is worth spiking in Phase 49 at all, given D-05/D-06 scope this phase to confirming the failure mode, not necessarily building around it.
   - Recommendation: Out of scope for this phase per CONTEXT.md's boundary ("No UI is built this phase... spike produces no code changes"); defer the fallback-design question to Phase 50, informed by this phase's confirmed failure matrix.
   - **Resolution:** Explicitly deferred to Phase 50 (out of scope for this spike) — no plan in this phase addresses the fallback-design question; Phase 50's planner should read this open question fresh alongside this phase's confirmed failure matrix.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode / `xcodebuild` | Building Islet.app with entitlement/Info.plist changes (SC #1, #4) | ✓ (existing project, confirmed via `project.pbxproj` reads) | Per existing project config | — |
| `osascript` / AppleScript runtime | SC #2 sanity checks | ✓ (ships with macOS) | — | — |
| A Spotify account (Premium or regular) | SC #3 | Per D-02, confirmed available | — | — |
| Spotify Developer Dashboard access | SC #3, D-01 | Assumed ✓ (free registration, no blocker known) | — | — |
| Local Apple Music library tracks + streaming-only tracks | SC #2 | Per D-05, confirmed available on dev hardware | — | — |
| `openssl`, `curl`, `python3` (for the PKCE shell script) | SC #3 harness | ✓ (ship with macOS / already used elsewhere in this toolchain) | — | — |

**Missing dependencies with no fallback:** None identified.

**Missing dependencies with fallback:** None — all spike-required tooling is already present on macOS or already resolved in the project.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (`IsletTests/` target, already present — confirmed via `project.pbxproj`) |
| Config file | Existing `Islet.xcodeproj` scheme; no new config needed |
| Quick run command | `xcodebuild test -scheme Islet -only-testing:IsletTests` (existing project convention) |
| Full suite command | `xcodebuild test -scheme Islet` |

**This phase does not add automated tests.** All four success criteria require real MediaRemote IPC, real AppleScript/TCC state, or a real network OAuth round-trip — none of which are unit-testable, mirroring this project's own documented precedent for `NowPlayingMonitor` itself ("real MediaRemote IPC / process lifecycle can't be unit-tested — see 04-VALIDATION.md... verified ON-DEVICE"). The existing `IsletTests` suite is unaffected and should stay green (no production code changes expected beyond the two entitlement/Info.plist additions, which are not independently unit-testable either).

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| Success Criterion #1 | `likeTrack()` send + effect confirmed on real Music.app/Spotify.app | manual-only, on-device | N/A — `checkpoint:human-verify` after triggering the throwaway hook | N/A |
| Success Criterion #2 | `current track`/`loved` matrix across library/streaming/play-pause states | manual-only, on-device (Terminal `osascript` acceptable) | N/A — `checkpoint:human-verify` per state combination | N/A |
| Success Criterion #3 | Spotify OAuth PKCE + `PUT /me/library` round-trip | manual-only, on-device (shell script + real account) | N/A — `checkpoint:human-verify` after running the PKCE script | N/A |
| Success Criterion #4 | TCC/Automation prompt-bug reproduction or honest rule-out | manual-only, on-device, from Islet.app's own binary | N/A — `checkpoint:human-verify`, non-reproduction is a valid documented outcome | N/A |

### Sampling Rate
- **Per task commit:** `xcodebuild build -scheme Islet -configuration Debug` (confirms the entitlement/Info.plist additions and any throwaway hook still compile) — matches this project's own Phase 22 precedent (`xcodebuild build` as the acceptance gate for spike scaffold tasks).
- **Per wave merge:** N/A — this is a single-wave spike phase per its scope.
- **Phase gate:** All four success criteria have a recorded, honest verdict (PASS/FAIL/PARTIAL/NOT-REPRODUCED, matching Phase 22's own PARTIAL-verdict precedent) before `/gsd:verify-work`.

### Wave 0 Gaps
None — no test-framework or fixture gap exists; this phase's verification is entirely on-device/manual by design, consistent with this project's existing spike-phase convention (Phase 22).

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Yes (Spotify OAuth) | Authorization Code + PKCE (`S256` challenge method) — no client secret ever stored client-side, matching Spotify's own documented recommendation for unsandboxed direct-distributed apps |
| V3 Session Management | Yes, deferred to Phase 50 | Access/refresh tokens belong in Keychain (mirroring `KeychainLicenseStore.swift`'s existing pattern) once production wiring begins — the spike's shell-script harness may hold the token only in local shell variables/terminal scrollback for the duration of the test, never written to a file or `UserDefaults` |
| V4 Access Control | Not directly applicable this phase | N/A — no multi-user access control surface introduced |
| V5 Input Validation | Minimal this phase | The spike script's manually-pasted `code` param should be treated as untrusted input if any future automation wraps it — not a concern for a human-run, one-off Terminal session |
| V6 Cryptography | Yes (PKCE `code_challenge`) | `S256` (SHA-256) code challenge method only — never the deprecated `plain` PKCE method; use `openssl`/`shasum` exactly as shown in Code Examples, not a hand-rolled hash |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Spotify Client Secret baked into a distributed, unsandboxed binary | Information Disclosure | PKCE flow (no client secret at all) — already the recommended/only viable flow per STACK.md |
| OAuth `code` interception via a non-loopback/non-HTTPS redirect URI | Spoofing | Use `http://127.0.0.1:<port>/callback` (loopback) for the spike script, matching Spotify's post-Feb-2025 redirect URI rules (bare `localhost` rejected, plain non-loopback `http://` rejected) |
| Spike-harness access token persisted somewhere durable (shell history, a committed script with a hardcoded token) | Information Disclosure | Never commit the shell script with a real token/Client ID filled in — keep the Client ID as a placeholder in any committed artifact, and treat the token as ephemeral, terminal-session-only for this spike |

## Sources

### Primary (HIGH confidence)
- Direct source reads: `Islet/Notch/NowPlayingMonitor.swift`, `Islet.entitlements`, `Islet.xcodeproj/project.pbxproj`, `Islet.xcodeproj/.../Package.resolved`, and the resolved SPM checkout at `~/Library/Developer/Xcode/DerivedData/Islet-.../SourcePackages/checkouts/mediaremote-adapter/` (`MediaController.swift`, `TrackInfo.swift`, `MediaRemoteAdapter.m`, `MediaRemote.h`, `MediaRemoteAdapterKeys.h`, `run.pl`, `README.md`, `git log`) — all fetched/read directly this session, 2026-07-20
- Spotify for Developers — `developer.spotify.com/documentation/web-api/concepts/quota-modes` (fetched directly today: 5-user Development Mode cap, Extended Quota criteria including 250k MAU/org-only requirement)
- Spotify for Developers — `developer.spotify.com/documentation/web-api/tutorials/february-2026-migration-guide` (fetched directly today: `PUT /me/library` URI-based request shape)
- Spotify for Developers — `developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow` (fetched directly today: exact PKCE endpoint/param shapes)
- Apple Developer Forums thread 798267 — "Apple Script for Music app no longer supports current track event" (fetched directly today: exact `-1728` error text, `FB19908171` bug number)
- Apple Developer Forums thread 792157 — "App doesn't trigger Privacy Apple Events prompt after a while" (fetched directly today: exact idle-time trigger scenario, `tccutil reset AppleEvents` reported ineffective)

### Secondary (MEDIUM confidence)
- `.planning/research/SUMMARY.md`, `STACK.md`, `PITFALLS.md`, `FEATURES.md` (this milestone's own prior research, 2026-07-19) — used as the baseline this document extends/corrects; Pitfall 1's specific "no like command" claim is superseded by this session's direct source read
- WebSearch — "Spotify Developer Dashboard quota modes Extended Quota Mode application criteria 2026" (corroborates the directly-fetched official docs above)

### Tertiary (LOW confidence)
- None used as load-bearing claims this session — all critical claims were either code-verified directly or fetched from official Spotify/Apple sources.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies; existing pin verified directly against `Package.resolved` and its actual checked-out source
- Architecture: HIGH — direct codebase reads of `NowPlayingMonitor.swift`, entitlements, and pbxproj settings
- Pitfalls: HIGH for Spotify policy and the `mediaremote-adapter` command-table correction (both fetched/read directly today); MEDIUM for the TCC-bug reproducibility question specifically (genuinely uncertain whether a fast repro proxy exists — flagged as Open Question 2, not asserted either way)

**Research date:** 2026-07-20
**Valid until:** ~14 days for the code-level findings (stable until the SPM pin changes); ~30 days for the Spotify policy findings (official, but Spotify has changed this policy before and STACK.md itself flags "re-verify at plan/execute time"); re-verify the Apple Music `-1728` bug status if this spike is executed after a macOS Tahoe point-release ships (Apple's DTS response suggested beta progress, no fixed timeline)
