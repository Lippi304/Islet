# Pitfalls Research

**Domain:** Adding trial enforcement, one-time paid licensing (Polar.sh), and real Developer-ID notarization to an existing shipped indie macOS menu-bar app (Islet)
**Researched:** 2026-07-05
**Confidence:** MEDIUM-HIGH (notarization/codesign mechanics and macOS Keychain behavior are HIGH confidence, well-documented; Polar.sh-specific operational details are MEDIUM — official docs are thin on rate limits/offline guidance, filled in with general licensing-industry patterns which are LOW-MEDIUM but directionally solid)

**Explicit scope guardrail:** This is a hobby project's first monetization pass, not enterprise DRM. Every mitigation below is chosen to be "annoying enough to stop casual reset-abuse," not "unbreakable." If a prevention strategy starts requiring server-side device fingerprinting, obfuscation, or anti-debugging, that is over-engineering — flag it and cut it.

---

## Critical Pitfalls

### Pitfall 1: Trial state stored only in UserDefaults/plist (trivially reset)

**What goes wrong:**
Storing `trialStartDate` only in `UserDefaults`/`~/Library/Preferences/<bundle-id>.plist` means any user can reset the trial for free by running `defaults delete <bundle-id>` or deleting the plist file directly — no reinstall even required. This is the single most common mistake in indie macOS trial implementations, because UserDefaults is the first API a Swift developer reaches for and it "just works" in every tutorial.

**Why it happens:**
UserDefaults is the path of least resistance — no imports, no error handling, no async. Developers don't think about the attack until a user posts "how to reset X app trial" on Reddit/forums.

**How to avoid:**
Store the trial marker in the **login keychain** (`kSecClassGenericPassword`, non-sandboxed app, no App Group needed) rather than UserDefaults. On macOS, Keychain items are **not** tied to the app bundle/container — unlike iOS, deleting or reinstalling the app on macOS does **not** remove Keychain items (this is a load-bearing platform difference: macOS Keychain persistence is independent of app lifecycle for non-sandboxed apps). This alone stops the "delete the app, reinstall, get another 3 days" attack without requiring any server component.

Proportionate implementation for this project:
- Write trial-start date to Keychain on first launch (one item, `kSecAttrAccount` = something app-specific, `kSecAttrAccessible` = `kSecAttrAccessibleAfterFirstUnlock` so it survives reboots without requiring unlock-state gymnastics).
- Also mirror it to UserDefaults for convenience reads — but treat Keychain as source of truth; if UserDefaults value is absent/earlier than Keychain value, trust Keychain (i.e., **the earliest of the two known dates wins for enforcement**, not the most recent) so a user can't extend by editing just the plist.
- Do **not** attempt hardware fingerprinting, System Integrity Protection bypass detection, or anti-tamper obfuscation — explicitly out of scope. A determined user who is willing to poke at Keychain Access or write a script to nuke the specific keychain item will always be able to reset it; the goal is raising the bar past "everyone does this by accident," not stopping the 1% who'd bother anyway.
- Accept, explicitly and in writing in the plan, that **some casual trial abuse is a cost of doing business** at this price point (€7.99) and scale (solo dev, small user base). Do not build a device-fingerprint-plus-server-side-first-seen-registry system for this — that is real over-engineering for a €7.99 utility.

**Warning signs:**
- Any code path that reads trial start exclusively from `UserDefaults.standard`.
- No fallback/reconciliation logic between two storage locations.
- QA testing only ever runs the trial once per machine (never verifies reinstall behavior).

**Phase to address:** Trial-enforcement phase (the phase that introduces `TrialService`/trial start-date persistence) — should be a foundational design decision, not a bolt-on fix later.

---

### Pitfall 2: License validation hard-fails with no retry/support path when Polar API/network is unavailable at first-purchase moment

**What goes wrong:**
User buys the license, gets a key (via email or checkout redirect), pastes it into the app, and at that exact moment either Polar's API is briefly down, the user's Wi-Fi hiccups, or a corporate/hotel network blocks the request. A naive implementation shows a raw error ("Network error: -1009") or silently fails, and the user — who just paid money — concludes the app is broken/a scam and requests a refund or leaves a bad review. This is the highest-consequence failure mode in the whole milestone because it happens at the exact moment of maximum purchase-regret risk.

**Why it happens:**
Developers test license validation almost exclusively on their own reliable home/office network, so the "network flaky at the worst possible time" path is rarely exercised. Additionally, a single validate call with no retry logic is the simplest thing to write first and often never gets revisited.

**How to avoid (resilient pattern, proportionate to scale):**
- Distinguish **network/transient errors** from **actual invalid-key errors**. Only show "this license key is invalid" for an explicit 4xx "key not found/revoked" response from Polar. For anything else (timeout, DNS failure, 5xx, no connectivity), show a clearly different message: "Couldn't reach the license server — check your connection and try again," with a visible **Retry** button.
- Add automatic retry with short backoff (2-3 attempts, few seconds apart) before surfacing any error to the user at all — most transient blips resolve within seconds.
- On failure after retries, **do not lock the user out of a key they just paid for.** Let them retry later; keep the pasted key stored locally (unvalidated) so they don't have to re-find/re-paste it, and re-attempt validation on next app launch or on a manual "Retry validation" button.
- Provide a visible support contact (email/Discord/whatever channel exists) directly in the failure state — "Still stuck? Email us at X" — so a paying customer always has a human escape hatch instead of a dead end.
- Log the failure locally (simple log file) so if the user does email support, you can ask them to send it rather than debugging blind.

**Warning signs:**
- Error message strings that are raw `Error.localizedDescription` dumps shown directly to the user.
- No distinction in code between "key invalid" and "request failed."
- No retry logic at all around the validate/activate network call.

**Phase to address:** Licensing/Polar-integration phase — specifically the "activate/validate flow" task. This should be tested by simulating airplane mode and a mocked 500/timeout response, not just the happy path.

---

### Pitfall 3: Offline-cached license state stored as a plain flippable boolean

**What goes wrong:**
Since the design explicitly validates once online then trusts a local cache indefinitely, the temptation is to store `isLicensed: Bool` (or `trialExpired: Bool`) in UserDefaults. This is trivially flipped with `defaults write <bundle-id> isLicensed -bool true` in Terminal — no reverse engineering skill required, just knowledge that the key exists (and app binaries/strings are easy to grep for likely key names).

**Why it happens:**
Same root cause as Pitfall 1: UserDefaults is the reflexive choice, and "cache the validated result" sounds like it just means "save a bool."

**How to avoid (proportionate — not paranoid-grade):**
- Store the cached license state in the **Keychain**, not UserDefaults, as the primary source of truth (same rationale/mechanism as Pitfall 1 — non-sandboxed macOS Keychain items are easy to write/read and are not casually editable via a documented CLI the way `defaults write` is).
- Store more than a bare bool: include the license key itself (or a hash of it), the last-validated timestamp, and ideally a simple locally-computed integrity value (e.g., HMAC or hash of `licenseKey + timestamp + a fixed app-embedded secret`) so a value copied from one field can't just be typed into another blindly. This is **not** meant to defeat a determined reverse engineer with a debugger — it only needs to defeat "type one Terminal command found in a forum post." Do not implement code signing of the cache, remote attestation, or anti-debugging — genuinely out of scope for a €7.99 utility.
- Re-validate opportunistically (e.g., once every N days when online) rather than never again — this bounds how stale/tampered state can drift before a legitimate re-check silently corrects it, without turning this into a "phone home every launch" always-online requirement (which would reintroduce Pitfall 2's failure mode as a *recurring* nuisance instead of a one-time one).
- Accept explicitly: a user willing to open Keychain Access and hand-edit an item, or attach a debugger, can still bypass this. That is out of scope to prevent. The bar is "harder than one documented Terminal command," not "unbreakable."

**Warning signs:**
- `UserDefaults.standard.bool(forKey: "isLicensed")` or similarly named keys anywhere in the codebase.
- Cache format is human-readable/guessable with no timestamp or key-material binding at all.
- No periodic re-validation — cache is genuinely "forever" with zero drift correction.

**Phase to address:** Licensing phase, same task as Pitfall 2 (the local cache is the other half of the validate flow) — plan should explicitly call out Keychain-not-UserDefaults as an acceptance criterion.

---

### Pitfall 4: Notarization failure from unsigned/incorrectly-signed nested MediaRemoteAdapter.framework or spawned perl helper

**What goes wrong:**
`notarytool submit` (or the older `altool`) rejects submissions when **any nested binary** inside the app bundle lacks a valid Developer ID signature with the hardened runtime enabled and a secure timestamp — this includes vendored frameworks like `MediaRemoteAdapter.framework`, not just the main executable. Common concrete failures seen in the wild: "The binary is not signed," "The signature does not include a secure timestamp," "The executable does not have the hardened runtime enabled," and nested-framework-specific signature mismatches when Xcode's automatic signing doesn't descend properly into an embedded framework that itself was built/vendored with a different signing identity or timestamp.

For this project specifically: `MediaRemoteAdapter.framework` is a **vendored, prebuilt** third-party framework (not built from this project's source), and the app **spawns `/usr/bin/perl` as a subprocess** at runtime. Spawning system binaries at runtime is not itself something `notarytool` inspects or blocks (the perl binary is Apple's own system binary already signed by Apple — you are not shipping/signing your own perl), but the app's *own* code that does the spawning must itself be correctly signed with the hardened runtime, and if the hardened runtime blocks or restricts child-process behavior, the relevant entitlement (e.g., disabling library validation if needed for how the adapter operates) must be present and justified.

**Why it happens:**
Xcode's "Sign to Run Locally" (used throughout regular development) does not exercise the same validation path as a real Developer ID + hardened runtime + notarization submission — the dry-run/local-dev signing is much more forgiving. The first time a full release-signed archive is built and submitted is often the first time these gaps surface, days or weeks after the actual code was written, disconnected from the original context.

**How to avoid:**
- Set the framework's "Embed & Sign" (not "Embed Without Signing") in Xcode's Frameworks/Libraries/Embedded Content settings for `MediaRemoteAdapter.framework` — this makes Xcode re-sign the vendored framework with *your* Developer ID during archive, which is required (the framework's own upstream signature, if any, is not sufficient — it must carry your team's signature to notarize as part of your app).
- Enable the hardened runtime on the target (`ENABLE_HARDENED_RUNTIME = YES`), and add **only** the specific entitlements actually required — if the adapter needs to invoke perl and load a helper dylib there, check whether `com.apple.security.cs.allow-unsigned-executable-memory` / `com.apple.security.cs.disable-library-validation` are genuinely necessary (do not blanket-add every hardened-runtime exception "just in case" — each one is both a notarization risk-surface and a real security weakening; add the minimum that makes the actual adapter flow work, verified by testing the signed build, not by assumption).
- Do a **local pre-flight validation** before ever calling `notarytool submit`: `codesign --verify --deep --strict --verbose=2 YourApp.app` and `spctl --assess --type execute -vvv YourApp.app` on the *actual archived, exported, Developer-ID-signed* build (not a debug build) to catch nested-signature problems before burning a submission cycle.
- Sign nested content **innermost-first**: sign `MediaRemoteAdapter.framework` (and anything nested inside it) before signing the outer app bundle — codesign order matters, and this is exactly the kind of bug `--deep` masks rather than fixes (avoid `codesign --deep` for the final production signing step in favor of explicit per-target signing, since `--deep` is described by Apple/community guidance as "almost never what you actually want" for complex bundles with multiple embedded binaries).
- Treat the first real notarization submission as its own testable milestone step, not a footnote at the end of a phase — budget time for at least 2-3 iteration cycles (each `notarytool submit --wait` round-trip is minutes, but diagnosing a signature issue from the returned log can take longer).

**Notarization vs. "uses a private API/spawns processes" — does this specifically increase rejection risk?**
Based on available research (MEDIUM confidence — Apple does not publish the exact scanner heuristics), notarization remains fundamentally a **malware/known-bad-signature scan**, not a policy review of *what* the app does — Apple's own documentation continues to describe it as automated scanning for known malicious content plus code-signing validation, not app-behavior review. There is no documented case found of notarization being rejected specifically *because* an app spawns subprocesses or bridges into private frameworks per se — legitimate apps (including this project's own reference points, e.g. TheBoringNotch, and many automation/scripting tools) ship notarized while doing exactly this. However, two real, adjacent risks exist and should not be dismissed:
1. Malware families have historically abused legitimate-looking, correctly-signed/notarized apps that fetch and execute payloads at runtime — meaning Apple's scanner behavior in this space has evolved and could tighten further without much notice. This is a "watch for future changes" risk, not a known current blocker.
2. Practically, the **actual signing correctness of the nested framework and hardened-runtime entitlement set** (Pitfall 4's main body) is a far more likely source of a real rejection than anything to do with the private-API bridging itself. Do not spend effort trying to "hide" the perl-spawning behavior from the scanner — that would be the actual red flag (obfuscation is a malware signal); ship it signed correctly and transparently.

**Warning signs:**
- Framework embed setting is "Embed Without Signing" instead of "Embed & Sign."
- `codesign --verify --deep --strict` on the archived build reports failures before you've even submitted to Apple.
- Notarization log (`notarytool log <submission-id>`) shows "The signature does not include a secure timestamp" or "is not signed" for anything other than the top-level app you expect.
- Testing only ever happens via local Xcode run/debug builds, never an actual exported+signed archive, until the day of intended release.

**Phase to address:** The dedicated "real notarization" phase in this milestone (moving from dry-run/local signing to Developer-ID + notarize + staple). Should include an explicit task to codesign-verify and spctl-assess the archived build locally before first submission, and a fallback/iteration budget rather than assuming one-shot success.

---

### Pitfall 5: Periodic re-validation timer fires mid-session and abruptly yanks the UI

**What goes wrong:**
If trial/license re-validation runs on a periodic timer (e.g., "re-check every 24h" or "re-check on each launch plus daily while running"), and it fires while the user is mid-interaction — island expanded, dragging a file into the shelf, mid-playback-control tap — an abrupt "trial expired, app locked" state change that yanks the currently-open UI out from under the user feels broken and hostile, and risks data loss (e.g., an in-progress drag-and-drop). This is a classic "technically correct enforcement, terrible UX" bug.

**Why it happens:**
Enforcement logic is usually written from the "is licensed: yes/no" state-machine perspective in isolation, without considering what UI state the app is in at the moment the check result changes state, because the developer building the check and the developer (same person, different day) building the UI don't cross-reference.

**How to avoid:**
- Never force-collapse or force-hide currently-open/interactive UI (expanded island, active drag operation, in-progress HUD) synchronously the instant a background re-check flips the licensed flag. Instead: apply the new locked state model at the **next natural transition point** — when the island next collapses on its own, or on next app launch — not by yanking the current interaction.
- If a hard lock must take effect immediately (e.g., trial truly expired), show it as a graceful, animated state change consistent with the app's existing spring/morph language (per project's existing `matchedGeometryEffect`/spring conventions) rather than an instant `NSAlert`-style interrupt or a blank/disabled UI mid-gesture. A brief "Trial ended" card that itself morphs in via the same island animation the rest of the app already uses is more in keeping with the polish bar this project has already set (per CLAUDE.md's Dynamic Island animation philosophy) than a jarring modal.
- Debounce/guard: don't run the re-validation check itself while the island is in an actively-interactive state (expanded/dragging) — defer the check (not the enforcement, the check itself) until the island returns to idle/collapsed, then apply results.
- Keep the periodic re-check interval generous (daily is plenty for a €7.99 one-time-purchase app — this is not subscription SaaS requiring tight revocation windows) to minimize how often this edge case can even occur.

**Warning signs:**
- Re-validation timer callback directly mutates `isExpanded = false` or disables UI synchronously with no state-transition awareness.
- No manual test performed of "expand the island, then simulate trial-expiry firing while expanded."
- Lockout UI implemented as a system alert/sheet rather than in the app's own animated visual language.

**Phase to address:** Trial-enforcement / lockout-UX phase — should include an explicit interaction-state check as an acceptance criterion, tested by manually triggering expiry while the island is open.

---

### Pitfall 6: Checkout-to-license-key handoff friction for a Dock-icon-less (LSUIElement) app

**What goes wrong:**
Two related frictions can cause purchase abandonment or confusion:
1. Opening a web checkout (Polar.sh hosted checkout page) from an `LSUIElement` background-agent app via `NSWorkspace.shared.open(url:)` opens the user's default browser — but because the app itself has no Dock icon and isn't a "normal" foreground app, after the user completes checkout in the browser and switches back, there's no obvious "come back to the app" affordance the way a Dock-icon app would provide (bounce, badge, Cmd+Tab entry). The user completes payment, then isn't sure how to return to Islet to actually enter/receive their license — increasing the chance they forget, or think nothing happened.
2. The checkout-to-key handoff itself: if the license key only arrives via **email** (typical Polar.sh flow — checkout completes, key is emailed), there's a context-switch gap between "just paid in browser" and "now go check email, copy key, switch back to a menu-bar app, find its settings, paste key." Each extra step is a documented drop-off point in purchase-completion UX generally; for a background/menu-bar app with no persistent visible window, this gap is worse than for a normal windowed app because the user has to actively remember the app exists and go find its icon in the menu bar again.

**Why it happens:**
Developers test the checkout flow themselves, already knowing exactly where the app's settings/license-entry UI lives — they don't experience the "wait, where did that app go" moment a real first-time customer does.

**How to avoid:**
- Before opening the checkout URL, `NSApplication.shared.activate(ignoringOtherApps: true)` on the app itself is not what's needed here (the browser needs focus, not the app) — instead, ensure the app's own menu-bar icon/status item remains an obvious, discoverable "return point": consider having the menu-bar icon show a distinct state (e.g., a subtle badge or color change) while a checkout is pending, so when the user does eventually click the menu-bar icon again, it's visually obvious the app is waiting for them to finish something.
- If Polar.sh supports a **success redirect URL** after checkout completion (check Polar's checkout configuration options — hosted checkouts commonly support a post-purchase redirect), prefer a custom URL scheme (`islet://license-activated?...` or similar) that the app registers to handle, so completing checkout in the browser can hand control straight back to the app automatically, rather than relying purely on the email round-trip. This removes an entire manual step (open email, copy key, switch app, paste) if Polar's flow supports passing the key or a claim token through the redirect.
- Regardless of whether a deep-link handoff is implemented, always also support **manual key entry** (paste from email) as the guaranteed-working fallback — don't make the deep link the *only* path, since email deliverability/user email-client friction is itself variable.
- Keep the "enter your license key" UI reachable in **one click from the menu-bar icon** at all times post-purchase (not buried in a preferences pane three clicks deep) for exactly the window of time right after a purchase when the user is actively trying to complete the flow.
- Pre-fill/auto-paste from clipboard if a license-key-shaped string is detected on clipboard when the license entry UI opens (nice-to-have, not required) — reduces friction for the common case of "just copied the key from the email."

**Warning signs:**
- No visible change to the menu-bar icon/UI state between "checkout opened" and "license entered."
- License entry UI requires navigating through multiple preference panes to reach.
- No investigation of whether Polar.sh's checkout supports a post-purchase redirect/webhook that could shortcut the manual copy-paste round trip.

**Phase to address:** Licensing/checkout-UX phase — should include a "cold start" manual test: as if for the first time, click buy, complete a real (or sandboxed/test-mode) Polar checkout, and time/count the steps back to a working licensed app with no prior knowledge of where the license-entry UI lives.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|--------------------|-----------------|------------------|
| Trial/license state in UserDefaults only | Fast to implement, no Keychain API friction | Trivially resettable, undermines the entire trial's purpose | Never for shipped v1 — Keychain is barely more code |
| Single validate call, no retry/backoff | Simpler code | First-purchase validation failures read as "app is broken," refund/review risk | Never — retry logic here is small and high-value |
| `codesign --deep` for final signing | One command, "just works" locally | Masks nested-signature issues that surface later as notarization rejections | Acceptable only for quick local dev-signing sanity checks, never for the release-signed archive |
| Blanket hardened-runtime entitlements (add everything "just in case") | Avoids trial-and-error during signing | Larger security-exception surface, looks worse in review, doesn't actually fix root cause if wrong entitlement chosen | Never — always add the minimum verified-necessary set |
| Hard real-time UI yank on license state change | Simple state machine, no extra transition logic | Feels broken/hostile mid-interaction, erodes trust in exactly the polished feel this project prioritizes | Never — the deferred-transition approach is a small addition |
| Device fingerprinting / server-side anti-abuse registry for trial resets | "Solves" reinstall abuse thoroughly | Massive scope increase, server infra, privacy questions, disproportionate to a €7.99 hobby-turned-sellable app | Not acceptable at this project's scale — explicitly out of scope |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|------------------|-------------------|
| Polar.sh license validation | Treating all non-200 responses as "invalid key" | Distinguish transient/network errors from explicit invalid/revoked-key responses; only the latter should ever say "invalid license" to the user |
| Polar.sh checkout | Assuming license key delivery is instant/synchronous with payment | Assume email delivery latency; support manual paste as the guaranteed path; investigate redirect/webhook options as an enhancement, not the only path |
| MediaRemoteAdapter.framework (vendored) | "Embed Without Signing" left as default, or assuming the vendor's own signature is sufficient | Set "Embed & Sign" so your Developer ID re-signs it during archive; verify with `codesign --verify --deep --strict` post-archive |
| `notarytool submit` | Submitting only after `--wait`ing once and assuming success on first try | Budget iteration; use `notarytool log <id>` on any rejection to get the actual per-binary failure reason before re-submitting blindly |
| Keychain (non-sandboxed macOS app) | Assuming Keychain behaves like iOS sandboxed Keychain (auto-cleared on delete) | macOS Keychain items for non-sandboxed apps persist independently of the app bundle — this is a feature to lean on here, not a bug to work around |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Re-validating license against Polar's API on every app launch or too frequently | Unnecessary network calls, slower cold start, more exposure to Pitfall 2's failure mode | Validate once at activation, then cache; re-validate on a generous interval (daily+) only, not every launch | Noticeable once launch performance or offline reliability is scrutinized — low risk at this app's scale, but cheap to get right from the start |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Storing license/trial state as human-readable, unbound plain values (bool/date with no integrity check) | Trivial `defaults write`/plist-edit bypass | Keychain storage + lightweight integrity binding (timestamp+key hash), as detailed in Pitfalls 1 & 3 — proportionate, not gold-plated |
| Over-broad hardened-runtime entitlements to "make notarization pass" | Weakens the actual security hardening notarization is meant to enforce, may itself draw scrutiny | Add only the specific, verified-necessary entitlement(s) for the perl-spawn/adapter-load path |
| Treating notarization as equivalent to "this app is reviewed/approved for behavior X" | False sense that private-API use is Apple-sanctioned; could create surprise if Apple's policy or scanner heuristics shift | Understand notarization = malware/signature scan only; keep the `NowPlayingService` abstraction (already planned per CLAUDE.md) so an adapter break/policy shift is a contained fix |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|------------------|
| Cryptic raw network error shown on first license validation | Paying customer thinks app/purchase is broken, requests refund | Friendly, differentiated error copy + retry + visible support contact (Pitfall 2) |
| Abrupt mid-session lockout | Feels hostile, breaks trust in a "polished" app | Defer enforcement to next natural UI transition point, animate consistently with existing island morph language (Pitfall 5) |
| No visible "return to app" cue after browser checkout | User forgets to come back, thinks nothing happened | Menu-bar icon state change + one-click access to license entry (Pitfall 6) |
| License entry buried in settings | Extra friction right when purchase intent is highest | Keep license-entry reachable in one click from the menu-bar icon |

## "Looks Done But Isn't" Checklist

- [ ] **Trial enforcement:** Looks done when trial correctly counts down and locks at day 3 on a normal run — verify it also survives app delete + reinstall (Keychain-backed, not just UserDefaults).
- [ ] **License validation:** Looks done when a valid key validates successfully online — verify behavior specifically with Wi-Fi disabled and with a simulated Polar 500/timeout, both on first-ever validation and on a cached-then-recheck validation.
- [ ] **Offline license cache:** Looks done when the app remembers "licensed" across launches — verify it isn't a plain flippable UserDefaults bool (`defaults write` test).
- [ ] **Notarization:** Looks done when `notarytool submit --wait` returns "Accepted" — verify with `spctl --assess --type execute -vvv` and an actual Gatekeeper double-click-from-Finder test on a *different, clean* Mac (or at minimum a fresh user account) before calling it shippable, since local dev machines often have prior overrides/trust that mask real Gatekeeper behavior.
- [ ] **Mid-session lockout:** Looks done when locking works on app launch — verify the specific case of triggering expiry/re-check while the island is expanded/mid-interaction.
- [ ] **Checkout-to-key flow:** Looks done when you (the developer) can complete it knowing where everything is — verify with a genuine "first time user" walkthrough, timing the steps from clicking Buy to having a working licensed app.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|----------------|-----------------|
| Trial state was UserDefaults-only and already shipped | LOW | Migrate to Keychain-backed storage in a point update; on first launch of the new version, if Keychain marker absent but UserDefaults marker present, seed Keychain from UserDefaults (accept that pre-existing reset-abusers keep their reset, not worth chasing) |
| Notarization rejected on submission | LOW-MEDIUM | Pull `notarytool log <submission-id>`, identify the specific unsigned/invalid binary or missing entitlement, fix signing config, re-archive, re-submit — typically a signing-config fix, not a code-behavior fix |
| Users report checkout confusion/abandonment post-launch | LOW | Add menu-bar pending-state indicator and/or investigate Polar redirect/deep-link handoff as a fast-follow update; doesn't require re-architecting the purchase flow |
| Mid-session yank complaints after release | LOW | Wrap enforcement application in a "defer until idle" check; small, isolated fix to the enforcement callsite, not the validation logic itself |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|-------------------|---------------|
| Trial reset via UserDefaults/reinstall | Trial-enforcement phase | Delete app + relaunch fresh copy; trial should NOT reset |
| Hard-fail license validation on network issues | Licensing/Polar-integration phase | Test with Wi-Fi off and with a mocked API timeout/500 on first-ever validation |
| Flippable boolean license cache | Licensing/Polar-integration phase (same task as above) | `defaults write <bundle-id> isLicensed -bool true` should have no effect |
| Notarization rejection from nested framework/hardened runtime | Real-notarization phase | `codesign --verify --deep --strict --verbose=2` and `spctl --assess -vvv` pass locally before first `notarytool submit`; clean-account Gatekeeper test after acceptance |
| Mid-session abrupt lockout | Trial-enforcement / lockout-UX phase | Manually trigger expiry while island is expanded; verify graceful, animated, non-destructive transition |
| Checkout-to-key handoff friction | Licensing/checkout-UX phase | Full cold-start purchase walkthrough timed and step-counted |

## Sources

- Faisal Bin Ahmed, "All the wrong ways to persist in-app purchase status in your macOS app" (Medium) — MEDIUM, corroborates UserDefaults-vs-Keychain persistence distinction: https://medium.com/@Faisalbin/all-the-wrong-ways-to-persist-in-app-purchase-status-in-your-macos-app-ce6eb9bcb0c3
- Apple Developer Forums thread on iOS Keychain auto-delete behavior (confirms iOS/macOS keychain lifecycle differs from app lifecycle) — MEDIUM-HIGH: https://developer.apple.com/forums/thread/36442
- Polar.sh official docs — License Keys feature overview: https://polar.sh/docs/features/benefits/license-keys — MEDIUM (confirms activate/validate split and activation-limit/machine-binding conditions; does not document rate limits or offline guidance explicitly)
- Polar.sh API reference — Validate License Key endpoint (existence/shape confirmed; full error taxonomy not retrievable via automated fetch) — LOW-MEDIUM: https://docs.polar.sh/api-reference/customer-portal/license-keys/validate
- Stanislav Katkov, "Software License management with Polar.sh" — real-world Go implementation notes on local license-file caching pattern (hash, activation_id, next_check_time) — MEDIUM: https://skatkov.com/posts/2025-05-11-software-license-management-for-dummies
- Keygen.sh, "How to Implement an Offline Licensing Model" — general offline-licensing/grace-period industry pattern — MEDIUM: https://keygen.sh/docs/choosing-a-licensing-model/offline-licenses/
- Apple Developer Documentation, "Resolving common notarization issues" — HIGH, official: https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution/resolving_common_notarization_issues
- Apple Support, "Gatekeeper and runtime protection in macOS" — confirms notarization = automated malware/signature scan, not behavior review — HIGH: https://support.apple.com/guide/security/gatekeeper-and-runtime-protection-sec5599b66df/web
- AppleInsider, "Malware bypassed macOS Gatekeeper by abusing Apple's notarization process" (Dec 2025) — MEDIUM, illustrates notarization's scope/limits and that it doesn't inspect runtime behavior deeply, relevant context for the "does spawning perl risk rejection" question: https://appleinsider.com/articles/25/12/23/malware-bypassed-macos-gatekeeper-by-abusing-apples-notarization-proccess
- Keystroke Countdown, "Signing Embedded Frameworks in an Embedded Framework" — practical nested-framework signing guidance — MEDIUM: https://keystrokecountdown.com/articles/signing/index.html
- `codesign` man page / community guidance on `--deep` being "almost never what you want" for complex bundles — HIGH (documented tool behavior): https://real-world-systems.com/docs/codesign.1.html
- Medium, Davion, "Framework in another framework in terms of code signing" — nested code-signature reference behavior — MEDIUM: https://medium.com/@davion/framework-in-another-framework-in-terms-of-code-signing-d9a78be51798
- Apple Developer Documentation, `LSUIElement` / Launch Services Keys — confirms agent-app behavior (no Dock icon, no automatic focus) — HIGH: https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement
- codestudy.net, "How to Make NSAlert the Topmost Window in macOS Menu Bar Apps (LSUIElement)" — corroborates focus/activation friction for agent apps — MEDIUM: https://www.codestudy.net/blog/make-a-nsalert-the-topmost-window/
- Project's own existing research (CLAUDE.md) — MediaRemote/mediaremote-adapter architecture, notarization-vs-App-Store-review distinction already established for this project — HIGH (primary project source)

---
*Pitfalls research for: Adding trial/licensing (Polar.sh) + real notarization to an existing shipped macOS app (Islet)*
*Researched: 2026-07-05*
