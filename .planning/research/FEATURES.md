# Feature Research

**Domain:** Trial + one-time-purchase licensing for an indie macOS menu-bar utility (Islet, adding trial/licensing to an already-shipped app)
**Researched:** 2026-07-05
**Confidence:** MEDIUM-HIGH (patterns cross-verified across multiple comparable apps; Polar.sh mechanics confirmed against official docs; some app-specific details are community-report quality, not vendor-confirmed)

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist in any trial+one-time-purchase indie Mac utility. Missing these makes the licensing feel amateurish or broken, even though they're separate from the core notch feature.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Trial starts automatically on first launch, no signup | Every comparable app (BetterDisplay, CleanShot X, Rectangle Pro) starts the clock the moment the app first opens — no email, no account creation. Requiring signup before trying the product is friction users don't expect from a $8 utility. | LOW | Persist a `firstLaunchDate` (or equivalent) locally at first run; compute days-remaining from it. |
| Visible days-remaining indicator somewhere reachable from the menu bar | Users need to know how much runway they have without hunting. BetterDisplay shows license/trial state under Settings > Pro; the pattern across this app category is "trial status lives in Settings," not a nagging dialog. | LOW | For Islet specifically (no Dock icon, no main window): put it in the Settings window, likely near the existing Settings sections (see Architecture Dependencies below). A menu-bar dropdown line ("Trial: 2 days left") is the standard supplementary spot for menu-bar-only apps. |
| A "Buy Now" / "Upgrade" button that opens the checkout page in the default browser | Universal pattern — BetterDisplay's Settings > Pro has a direct "Buy BetterDisplay Pro" button; CleanShot X, Bartender do the same. Users expect one click from inside the app to the purchase page, not "go find the website yourself." | LOW | `NSWorkspace.shared.open(URL)` to the Polar.sh checkout link. |
| A license key entry field, in the same Settings surface as the Buy button | Every comparable app puts "enter your license key" directly adjacent to "buy a license" — same screen, so the purchase-to-activation loop is one context, not a scavenger hunt across app + email + settings. | LOW | Paste-friendly `NSTextField`/SwiftUI `TextField` with trimming of whitespace/newlines (a well-documented pasted-key pitfall) before validation. |
| License key recovery / re-entry after reinstall or new Mac | Users reinstalling macOS or moving to a new Mac expect to re-enter the same key and have it just work — not have to repurchase. Rectangle Pro solves this via Paddle's `my.paddle.com` self-service; Polar's customer portal is the equivalent. | LOW-MEDIUM | With Polar: license key validation via API means re-entering the same key on a new install re-validates (and, if you enable activation limits, may need old-device deactivation — see Anti-Features below on limits). |
| Trial state persists across app restarts and (ideally) reinstalls of the same binary | If quitting/relaunching resets the trial, that's an obvious, immediately-discovered bypass — and worse, a legitimate user who reinstalls after a crash could get confused about a "reset" trial in the wrong direction (BetterDisplay users have filed complaints in the *opposite* direction — legitimately having trial time wrongly wiped, see Pitfalls in PITFALLS.md file question). | LOW-MEDIUM | Store trial-start timestamp somewhere UserDefaults-adjacent is fine for v1 (this is a low-stakes $8 utility, not DRM); just don't reset it on ordinary app updates. |
| Clear, human-readable trial countdown language ("2 days left in your trial", not raw dates/timestamps) | Matches how every comparable app phrases it — plain "X days left" is the near-universal phrasing, it's the mental model users already have from every other trialware app (browser extensions, iOS apps, etc). | LOW | Simple string formatting off the computed days-remaining integer. |

### Differentiators (Competitive Advantage)

Not required, but would make the trial/licensing experience feel more polished than the median utility in this category — directly serves the project's "polished, possibly sellable" goal.

| Feature | Value Proposition | Complexity | Notes |
|---------|--------------------|------------|-------|
| Deep-link auto-fill of the license key after web checkout (`islet://license?checkout_id=...`) | Removes the single biggest friction point in the whole flow: manual copy-paste of a key from an email or browser tab back into the app. Polar's checkout `success_url` supports a `checkout_id={CHECKOUT_ID}` placeholder specifically so an app can register a custom URL scheme, receive the checkout ID, and complete the fetch itself — this is a known, documented Polar mechanism, not a hack. Almost no comparable indie utility (BetterDisplay, CleanShot X, Rectangle Pro all rely on Paddle email-delivered keys with manual copy-paste) bothers to do this, so it's a genuine differentiator. | MEDIUM | Requires: (1) `CFBundleURLTypes` entry for a custom scheme in Info.plist, (2) an `NSApplicationDelegate` URL-open handler, (3) success_url configured as `islet://license?checkout_id={CHECKOUT_ID}`, (4) app calls Polar's API (or a tiny serverless relay, since exposing your Polar access token in the client app is a security anti-pattern — see Anti-Features) to resolve `checkout_id` → license key, (5) falls back gracefully to manual paste if the deep link doesn't fire (user closed browser tab, etc). |
| A one-time, explicit "Start your 3-day trial" moment (not silent) | Silent trial start is table stakes for *not annoying* users, but a single, dismissible first-launch welcome moment ("Welcome to Islet — your 3-day trial has started") sets correct expectations up front and avoids the surprise of a lockout 3 days later with no warning it was ever "on the clock." This is a differentiator specifically because Islet has *no main window* — without an explicit moment, a user might never open Settings during the entire trial and get blindsided by the hard lockout. | LOW-MEDIUM | A one-shot `NSAlert` or a small SwiftUI sheet shown once at first launch (flag persisted so it never reappears). Given the hard-lockout choice below, this is close to load-bearing for fairness/UX, not purely a "nice to have" — flag this to the roadmapper as effectively-required given the hard-lockout decision. |
| Menu-bar icon subtle state change in the final trial day ("last day" visual cue) | A quiet nudge (e.g., icon tint change, or a one-time system notification "1 day left in your Islet trial") the day before lockout reduces the shock of hard lockout and gives users a chance to buy before losing functionality. No comparable app was found doing exactly this, but it directly mitigates the known backlash pattern against hard lockouts (see Anti-Features / Pitfalls). | LOW | A single local notification (`UNUserNotificationCenter`) fired once when days-remaining crosses into the last 24h; must not repeat/spam. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem reasonable but create disproportionate complexity or risk for a solo-dev $8 utility.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|------------------|-------------|
| Client-side embedded Polar API access token for direct license validation calls from the Mac app | Seems simpler — app calls Polar API directly with the org access token to validate/activate keys. | Any access token embedded in a distributed, non-sandboxed macOS binary can be extracted (strings, debugger) trivially, exposing your Polar org token — used to mint/revoke keys, read customer data. Community write-ups on Polar's licensing (e.g., LicenseSeat's critique) specifically flag Polar's license-key benefit as a "bolt-on" with no built-in device fingerprinting or offline validation designed for this. | Use Polar's public, purpose-built `/v1/customer-portal/license-keys/validate` and `/activate` endpoints, which are designed to be called from an untrusted client using the license key itself as the credential (not an org token). Never ship the org-level Polar access token in the app bundle. |
| Hardware-fingerprint-bound license activation with strict device limits enforced client-side | Feels like "real" software protection against key sharing. | Massive complexity for a $7.99 impulse-buy utility; every hour spent here is an hour not spent on the core island experience. Also actively backfires: Rectangle Pro's 3-device Paddle-managed limit already generates support-burden discussions (users needing to deactivate old Macs manually) — and that's with Paddle doing the heavy lifting. Rolling your own is strictly worse ROI for a solo dev. | Use Polar's built-in, opt-in activation-limit feature (simple count, e.g. allow 3-5 activations) if you want *any* limit at all — but this is optional, not required, for v1. Simplest v1: no activation limit at all, just "does this key validate" — casual key sharing at the $7.99 price point is not worth building anti-piracy infrastructure to prevent. |
| Subscription / recurring billing | Recurring revenue is tempting and Polar supports subscriptions natively. | The user has already explicitly decided one-time €7.99 purchase — building subscription billing, renewal emails, and dunning flows is out of scope and directly contradicts the chosen model. Flagging only so the roadmapper doesn't accidentally scope subscription-shaped code (e.g. periodic re-validation "phone home" checks) that isn't needed for a one-time purchase. | One-time purchase, one-time validation (with optional periodic re-validation purely to detect *refunds/chargebacks*, not to enforce a subscription — see Pitfalls). |
| In-app checkout (embedded web view / native payment sheet) instead of browser handoff | Feels more "native" / seamless to not leave the app. | Every comparable app in this category (BetterDisplay/Paddle, CleanShot X/Paddle, Rectangle Pro/Paddle) hands off to the default browser for checkout — payment processors want their own hardened, regularly-updated checkout surface (fraud rules, 3DS, updated ToS) which an embedded/stale web view inside your app would not get automatically. Polar's checkout is also designed as a hosted page, not an embeddable SDK for native apps. | `NSWorkspace.shared.open()` to a Polar-hosted checkout URL in the user's real browser; bring the user back via the deep-link success_url covered above. |
| Full "account" system (sign in, password, cross-device sync of purchase state) | Feels more robust / modern. | Wildly over-scoped for a one-time-purchase $7.99 utility with no cloud sync feature elsewhere in the app. Polar's customer portal already gives users self-service license lookup by purchase email — no separate account system needed. | Rely on Polar's existing customer portal (by purchase email) for license lookup/recovery; the app itself stays account-less, matching its current architecture. |

## Feature Dependencies

```
[Trial state persistence]
    └──requires──> [First-launch detection] (already trivial: app has no existing "first run" flag — needs adding)

[License key entry + validation]
    └──requires──> [Polar.sh product + license-key benefit configured server-side]
                       └──requires──> [Polar.sh account, product, checkout link] (external, non-code dependency)

[Hard lockout behavior]
    └──requires──> [Trial state persistence] AND [License key validation]
                       (lockout gate must check: is trial active OR is a valid license present)

[Deep-link auto-fill] (differentiator)
    └──requires──> [Custom URL scheme registration] AND [License key entry UI to autofill into]
    └──enhances──> [License key entry + validation] (removes manual copy-paste step)

[First-launch welcome/trial-start moment] (differentiator, effectively required given hard lockout)
    └──requires──> [First-launch detection]
    └──mitigates──> [Hard lockout] backlash (sets expectations before the clock starts)

[Last-day nudge notification] (differentiator)
    └──requires──> [Trial state persistence] (needs accurate days-remaining)
    └──mitigates──> [Hard lockout] backlash
```

### Dependency Notes

- **Hard lockout requires trial persistence AND license validation to both exist first:** the lockout gate is a boolean check (`trialActive || validLicense`) — both underlying seams must be built and tested before lockout logic can be wired in, otherwise you risk locking out every user including legitimate trial users (a launch-blocking bug class). This strongly suggests trial-state and license-validation should be built and tested as pure, independently-testable seams (consistent with this project's existing pattern of pure seams — see PROJECT.md/ARCHITECTURE.md conventions) *before* the lockout gate touches any UI.
- **Deep-link auto-fill enhances but does not block the core license flow:** it should be scoped as an add-on layer on top of a working manual paste-and-validate flow, not a prerequisite. If the deep link fails to fire (browser closed, scheme not registered correctly on first run, etc.), manual paste must still work as the fallback — build manual-paste-and-validate first, deep-link second.
- **First-launch welcome moment mitigates hard-lockout backlash:** given the user's explicit choice of a hard lockout, the welcome/trial-start moment is not purely optional — it's the main lever available to prevent the "the app suddenly stopped working with zero warning" complaint pattern seen in this app category (see Pitfalls file). Recommend treating it as near-mandatory in scoping, even though it's categorized as a "differentiator" above.

## MVP Definition

### Launch With (v1 of this milestone)

Minimum viable product for the trial+licensing milestone — validates the monetization mechanism without gold-plating.

- [ ] Silent local trial-start timestamp persisted on first launch — foundation for everything else
- [ ] One-time first-launch "Your 3-day trial has started" moment (sheet or alert) — sets expectations before the hard-lockout clock runs; near-mandatory given the hard-lockout choice
- [ ] Days-remaining indicator in the Settings window — table stakes, users need to check status
- [ ] "Buy Now" button in Settings opening the Polar.sh checkout URL in the default browser — table stakes
- [ ] Manual license-key entry field in Settings (paste-friendly, trims whitespace, clear validate/error states) — table stakes, and the guaranteed-to-work fallback path
- [ ] License key validation against Polar's customer-portal `/validate` (and `/activate` if using activation limits) API — core mechanism
- [ ] Hard lockout: when trial has expired and no valid license is present, the island/menu-bar functionality is disabled per the user's explicit product decision — the core requirement of this milestone

### Add After Validation (v1.x)

Features to add once the core trial→purchase→unlock loop is proven to work end-to-end on-device.

- [ ] Deep-link auto-fill (`islet://license?checkout_id=...`) to remove manual copy-paste — biggest UX upgrade, but only after the manual flow is solid
- [ ] Last-day nudge notification before lockout — reduces hard-lockout backlash, but not blocking for the mechanism to work
- [ ] Menu-bar icon subtle "last day" visual state — polish layer on top of the nudge notification

### Future Consideration (v2+)

Features to defer until there's evidence they're needed (e.g., support requests, abuse reports).

- [ ] Activation-limit enforcement / multi-device management UI — only needed if key-sharing becomes an observed problem; Polar supports this natively so it's low-cost to add later, not a v1 blocker
- [ ] Periodic re-validation ("phone home") purely to catch refunds/chargebacks — defer until there's actual refund abuse; adds complexity and offline-use edge cases (what happens if the check fails while the user is offline — must fail open, not closed)

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|----------------------|----------|
| Trial-start persistence | HIGH | LOW | P1 |
| First-launch welcome/trial-start moment | HIGH (given hard lockout) | LOW | P1 |
| Days-remaining indicator in Settings | HIGH | LOW | P1 |
| Buy Now button → Polar checkout | HIGH | LOW | P1 |
| Manual license key entry + validation | HIGH | LOW-MEDIUM | P1 |
| Hard lockout gate | HIGH (explicit product requirement) | MEDIUM | P1 |
| Deep-link auto-fill of license key | MEDIUM-HIGH | MEDIUM | P2 |
| Last-day nudge notification | MEDIUM | LOW | P2 |
| Menu-bar icon "last day" state | LOW-MEDIUM | LOW | P3 |
| Activation-limit / multi-device management | LOW (at this scale) | MEDIUM | P3 |
| Periodic re-validation for refund detection | LOW | MEDIUM | P3 |

**Priority key:**
- P1: Must have for this milestone's launch
- P2: Should have, add once P1 is proven on-device
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | BetterDisplay (Paddle) | Rectangle Pro (Paddle) | CleanShot X (Paddle) | Islet's Planned Approach |
|---------|------------------------|--------------------------|------------------------|---------------------------|
| Trial length | 14 days, unlimited features | Not publicly documented in sources found | 7-day equivalent implied by Paddle norms (not confirmed) | 3 days (explicit product decision, shorter than typical — flag: shortest trial found among comparables, see Pitfalls) |
| Trial start | Silent on first open | Silent on first open (typical Paddle-app pattern) | Silent on first open | Silent persistence + explicit one-time welcome moment (differentiator vs. comparables) |
| License entry location | Settings > Pro tab | Settings window, General tab | Dedicated License Manager web portal + in-app field | Existing Settings window (new section) |
| Key delivery | Email from Paddle | Email from Paddle | Email from Paddle | Polar checkout page + email; deep-link auto-fill planned as differentiator |
| Multi-device limit | Not strictly enforced found in sources | 3 simultaneous activations via Paddle | Managed via License Manager portal | Undecided for v1 — recommend no limit at v1, Polar activation limits available if needed later |
| Expiry behavior | "Unlicensed, Trial Expired" state; free tier features remain for personal use (soft) | Not documented in sources found | Not documented in sources found | Hard lockout (explicit product decision — stricter than all comparables found) |
| Payment processor | Paddle | Paddle | Paddle | Polar.sh (per project decision) |

## Sources

- Polar.sh official docs — checkout success_url with `checkout_id={CHECKOUT_ID}` placeholder, license-key `/activate` and `/validate` customer-portal API endpoints, activation limits, metadata propagation to Order/Subscription. (HIGH — official docs, `polar.sh/docs`, `polar.apidocumentation.com`)
- LicenseSeat "Alternative to Polar.sh" critique — Polar's license-key benefit described as a bolt-on with no device fingerprinting, no offline validation, no native desktop SDKs. (MEDIUM — vendor-competitor source, directionally useful but has an incentive to critique Polar; treated as a caution flag, not gospel)
- BetterDisplay (`waydabber/BetterDisplay`) GitHub wiki "Getting a Pro License" and support discussions — 14-day unlimited trial, Paddle email delivery, Settings > Pro activation, "Unlicensed, Trial Expired" soft-lock state, community complaint about trial state being wrongly reset by a settings-reset action. (MEDIUM-HIGH — official project wiki + first-party GitHub discussions)
- Rectangle Pro Community discussion #154 (`rxhanson/RectanglePro-Community`) — Paddle-based purchase/activation flow, 3-device activation limit, Settings window General tab deactivation, `my.paddle.com` self-service recovery. (MEDIUM — community discussion, not official vendor docs, but detailed and consistent)
- CleanShot X buy/pricing/FAQ pages and License Manager (`licenses.cleanshot.com`) — Paddle email-delivered key, dedicated License Manager portal for multi-device management. (MEDIUM — official product pages, but activation-screen specifics not directly verified)
- Apple Developer documentation — "Defining a custom URL scheme for your app" (`CFBundleURLTypes`, app delegate URL handling). (HIGH — official Apple docs)
- General UX validation-pattern sources (Medium, Auth0 community) on trimming whitespace from pasted input and inline validation-error timing. (MEDIUM — general UX best-practice consensus, not Mac-specific)
- Community reports on trial-lockout variance (Viscosity persistent nag vs. BetterDisplay hard "Trial Expired" state) — confirms both soft-nag and hard-lockout patterns exist in the wild, with no single dominant convention. (LOW-MEDIUM — WebSearch-aggregated summary of scattered community reports, not a systematic survey)

---
*Feature research for: trial + one-time-purchase licensing in an indie macOS menu-bar utility*
*Researched: 2026-07-05*
