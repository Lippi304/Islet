# Requirements: Notch — Dynamic Island for Mac

**Defined:** 2026-07-05
**Core Value:** The notch becomes a beautiful, reliable "island" that shows now-playing media and reacts when you plug in the charger or connect a device — it must feel native, smooth, and as polished as the iPhone Dynamic Island.

## v1.1 Requirements

Islet becomes a real, sellable product: a 3-day trial, a one-time €7.99 purchase via Polar.sh, hard lockout on trial expiry, and real Developer-ID notarized distribution. Each maps to roadmap phases.

### Trial Period (TRIAL)

- [ ] **TRIAL-01**: Trial starts silently on first launch, with the start date persisted tamper-resistantly (Keychain, survives app reinstall) — not trivially reset via `defaults delete` or reinstalling the app
- [ ] **TRIAL-02**: User sees a one-time, explicit "your 3-day trial has started" notice on first launch, so the hard-lockout clock is never a silent surprise
- [ ] **TRIAL-03**: User can see the number of trial days remaining at any time from the Settings window

### Purchase & Licensing (LIC)

- [ ] **LIC-01**: User can click a "Buy Now" button in Settings that opens the Polar.sh checkout page (one-time €7.99 purchase) in the default browser
- [ ] **LIC-02**: User can paste a purchased license key into a field in Settings; the key is validated once online against Polar.sh, then the validated state is cached locally (Keychain) so the app keeps working fully offline afterward
- [ ] **LIC-03**: When the trial has expired and no valid license is present, the app's functionality (the island) is fully locked until a valid license key is entered

### Distribution (DIST)

- [ ] **DIST-01**: The app is signed with a real Developer ID, notarized via `notarytool`, and stapled — replacing the v1.0 dry-run placeholders — so purchasers see no Gatekeeper warning on first launch

## v2 Requirements

Deferred to a future release. Carried over from the v1.0/v1.0.1 backlog (unchanged) plus this milestone's own fast-follow items.

### Later Features

- **SHELF-01**: File shelf — drag-and-drop tray at the notch to temporarily hold files, then drag them back out / share / AirDrop
- **HUD-01**: System HUDs — replace the default volume / brightness / battery overlays with notch-based HUDs
- **TMR-01**: Timer — start and watch a countdown timer as a live activity in the island
- **LIC-04**: Deep-link auto-fill of the license key after web checkout (`islet://license?checkout_id=...`) — removes manual copy-paste; add once the manual flow is proven solid on-device
- **TRIAL-04**: Last-day nudge notification before lockout — reduces hard-lockout backlash; not required for the core mechanism to work

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Subscription / recurring billing | User explicitly chose one-time €7.99 purchase; Polar supports subscriptions but building renewal/dunning flows would contradict the chosen model |
| Embedding a Polar.sh org access token client-side | Any token shipped in a non-sandboxed binary is trivially extractable; only the public, purpose-built `/validate`/`/activate` license-key endpoints (keyed by the license key itself) are called from the app |
| Hardware-fingerprint-bound activation limits / strict multi-device enforcement | Disproportionate complexity for a €7.99 impulse-buy utility; casual key sharing at this price point is an accepted cost, not something to build anti-piracy infrastructure to prevent (Polar's built-in activation-limit feature remains available later if abuse is observed) |
| In-app/embedded checkout (web view or native payment sheet) | Every comparable app hands off to the default browser; Polar's checkout is a hosted page, not an embeddable SDK, and payment processors want their own hardened, regularly-updated checkout surface |
| Full account system (sign-in, password, cross-device purchase sync) | Wildly over-scoped for a one-time-purchase utility; Polar's customer portal (lookup by purchase email) already covers license recovery without the app needing its own accounts |
| Periodic "phone home" re-validation for refund/chargeback detection | Adds offline-use edge cases (must fail open, not closed) for a benefit (catching refund abuse) with no evidence of being a real problem yet; defer until there's actual signal |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| TRIAL-01 | TBD | Pending |
| TRIAL-02 | TBD | Pending |
| TRIAL-03 | TBD | Pending |
| LIC-01 | TBD | Pending |
| LIC-02 | TBD | Pending |
| LIC-03 | TBD | Pending |
| DIST-01 | TBD | Pending |

**Coverage:**
- v1.1 requirements: 7 total
- Mapped to phases: 0 (roadmap not yet created)
- Unmapped: 7

---
*Requirements defined: 2026-07-05*
