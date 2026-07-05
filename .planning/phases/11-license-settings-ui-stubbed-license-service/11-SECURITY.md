# SECURITY — Phase 11: License Settings UI (Stubbed License Service)

**Audit date:** 2026-07-05
**ASVS level:** L1 (default)
**block_on:** high (block on HIGH+ severity open threats)
**Result:** SECURED — 5/5 threats resolved (4 mitigated + verified, 1 accepted)

This audit VERIFIES the mitigations declared in the Phase 11 `<threat_model>` blocks
(`11-01-PLAN.md`, `11-02-PLAN.md`) against the implemented code. It does not scan for
new threats. Every claim below is backed by a grep/read match at a cited `file:line`.

---

## Threat Verification

| Threat ID | Category | Disposition | Status | Evidence |
|-----------|----------|-------------|--------|----------|
| T-11-01 | Elevation of Privilege | mitigate | CLOSED | `Islet/Licensing/LicenseService.swift:15-20` (header documents DEBUG-only scaffold + Phase 12 file deletion before Phase 13); `#if DEBUG` gate wraps the compare at `:49-57` — Release rejects every key (`:56`). |
| T-11-02 | Elevation of Privilege | mitigate | CLOSED | `Islet/Licensing/LicenseState.swift:29` — `var sessionActivated = false` is a plain in-memory var, no persistence. `status` (`:40-68`) never reads the nudge key; only `debugOverrideKey` is read (`:42`). Nudge key `license.activationNudge` is WRITE-ONLY: sole reference is the write at `Islet/SettingsView.swift:177` (grep: 1 hit, no read-back). |
| T-11-03 | Tampering | mitigate | CLOSED | Key handled as opaque string: `trimmingCharacters` + `==` only (`LicenseService.swift:51-53`). `enteredKey` reaches only the empty-check trim (`SettingsView.swift:143`) and `licenseService.activate` (`:166`) — grep of all 4 `enteredKey` uses shows no URL/shell/log sink. No `print`/`NSLog`/`os_log`/logger of the key anywhere in `SettingsView.swift` or `Licensing/`. |
| T-11-04 | Tampering | mitigate | CLOSED | `SettingsView.swift:129-133` — Buy Now opens a hardcoded constant `URL(string: "https://lippi304.xyz/projects/islet/buy")!` via `NSWorkspace.shared.open`; no `enteredKey` / user input flows into the URL. (URL updated post-plan from `getislet.app` per T-11-04 note; still a hardcoded constant.) |
| T-11-SC | Tampering (supply chain) | accept | CLOSED (accepted) | `project.yml` NOT modified in any Phase 11 commit (`git log 3c85487^..HEAD -- project.yml` → empty). The only SPM package (`mediaremote-adapter`, `project.yml:17-19`) is pre-existing from Phase 04. Both plan SUMMARYs declare `tech-stack.added: []`. See Accepted Risks below. |

---

## Accepted Risks Log

### T-11-SC — No package installs this phase (accepted)
Phase 11 installs no new SPM/npm/pip/cargo dependency. Verified: no Phase 11 commit
touched `project.yml`; the sole package entry (`ejbills/mediaremote-adapter`) predates
this phase. Nothing to slopcheck. **Accepted — no residual supply-chain surface added.**

### T-11-01 residual — DEBUG magic key present in this non-release phase (accepted)
The `ISLET-DEMO-OK` scaffold key exists in `StubLicenseService`. It is `#if DEBUG`-gated
(rejected in Release) and documented for full removal in Phase 12 before the Phase 13
distribution. Phase 11 is not a public release, so the residual is **accepted for this
phase only**. Carry-forward gate: Phase 12 MUST delete `LicenseService.swift`'s stub /
replace with `PolarLicenseService` before any notarized build ships.

---

## Unregistered Flags

None. Neither `11-01-SUMMARY.md` nor `11-02-SUMMARY.md` contains a `## Threat Flags`
section, and no new attack surface was introduced beyond the four registered threats.
The one new UserDefaults key (`license.activationNudge`) is registered under T-11-02 and
verified write-only.

---

## Security Audit 2026-07-05
| Metric | Count |
|--------|-------|
| Threats found | 5 |
| Closed | 5 |
| Open | 0 |

`threats_open: 0` · `register_authored_at_plan_time: true` — all plan-time threats verified against code.

---

## Auditor Notes
- Implementation files were treated as READ-ONLY; none were modified.
- `#else` Release branch of the magic-key compare (`LicenseService.swift:54-56`) is
  belt-and-suspenders beyond the plan's "optional" `#if DEBUG` gate — a stronger posture
  than required.
- Live-unlock relies on the Phase 10 `UserDefaults.didChangeNotification` →
  `updateVisibility()` arbiter; SettingsView adds no second window show/hide site
  (confirmed: no `orderFront`/`orderOut` in the file), consistent with the entitlement
  arbiter staying single-sourced.
