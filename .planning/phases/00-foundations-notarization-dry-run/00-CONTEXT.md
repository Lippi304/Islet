# Phase 0: Foundations & Notarization Dry Run - Context

**Gathered:** 2026-06-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 0 delivers a **runnable but feature-less app**: a menu-bar-only background agent
(no Dock icon) named **Islet**, with a working "Launch at Login" toggle living in a minimal
Settings window — **plus** a proven, scripted `sign → notarize → staple` pipeline captured as
a repeatable script and exercised as far as possible on this hello-world build.

No island, no overlay window, no activities. Just the app shell, the launch-at-login plumbing,
and the release toolchain.

**Scope note (important for planning):** Because the Apple Developer account is deferred
(see D-01), the *actual* notarization + clean-second-Mac open (Phase 0 success criterion #3)
is **intentionally not executed in this phase** — it is prepared, scripted, and documented now,
then executed at Phase 6 (where the roadmap already re-verifies notarization). Do NOT treat the
un-run notarization as a Phase 0 blocker.
</domain>

<decisions>
## Implementation Decisions

### Apple Developer Account & Notarization
- **D-01:** The Apple Developer Program account ($99/yr) is **deferred** — purchased only once the
  product is publish-ready and the user is confident about releasing. NOT acquired during Phase 0.
- **D-02:** Phase 0 "done" definition: (a) a locally signed build runs as a menu-bar agent;
  (b) a `.dmg` artifact is built; (c) the FULL `sign → notarize → staple` flow is captured as a
  **repeatable, commented shell script** with clearly marked placeholders for the Developer ID
  identity and Apple ID / notary credentials; (d) Gatekeeper block-behavior is demonstrated locally.
  The real `notarytool submit` + `stapler staple` + clean-second-Mac open are a **documented
  carry-over executed at Phase 6**.
- **D-03:** Local dev signing uses **ad-hoc / "Sign to Run Locally"** (`codesign -s -`) — sufficient
  because notarization is deferred. No paid Developer ID cert needed now.
- **D-04:** **No second Mac available.** Gatekeeper behavior is verified on this Mac by setting the
  `com.apple.quarantine` attribute + running `spctl` assessment, documenting the expected
  "unidentified developer" block on the un-notarized build and what notarization will change.
- **D-05:** Distribution artifact format = **`.dmg`** (disk image), built in Phase 0 even though
  notarization runs later.

### macOS Target
- **D-06:** Deployment floor = **macOS 14.0 (Sonoma)**. Maximizes reach. Now Playing (Phase 4)
  requires macOS 15.4+ and degrades via the NOW-03 "unavailable" fallback below that;
  `SMAppService` (launch-at-login) requires 13+ — satisfied.

### App Identity
- **D-07:** Working display name = **"Islet"** (changeable later; final product name still TBD per PROJECT.md).
- **D-08:** Bundle identifier = **`com.lippi304.islet`** (lowercase). Stable — launch-at-login
  registration depends on it, so it must not change casually.

### Menu Bar & Settings
- **D-09:** Build a **minimal Settings window now** (SwiftUI) containing the Launch-at-Login toggle
  plus a version/build label. This is the foundation Phase 6 (APP-03) extends.
- **D-10:** Menu-bar dropdown = **"Settings…"** (opens the settings window) + **"Quit Islet"**.
- **D-11:** Menu-bar status item icon = a simple **monochrome SF Symbol as a template image**
  (capsule / notch-like), easily swappable later.

### Claude's Discretion
- Launch-at-login implementation via `SMAppService` (ServiceManagement) — already the project
  standard per CLAUDE.md; registration/error handling, the exact SF Symbol name, app & version
  number scheme, the repo location of the build script (e.g. `scripts/`), the Xcode-artifact
  `.gitignore`, the hardened-runtime flag (`--options runtime`) inside the script, the minimal
  entitlements (un-sandboxed per CLAUDE.md), and the placeholder `.app` icon.

### Folded Todos
(None — no pending todos matched this phase.)
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project tech stack & toolchain (primary for Phase 0)
- `CLAUDE.md` — the full recommended stack and, specifically: the **"Installation / setup"**
  section (Xcode project settings: SwiftUI, Swift 5 language mode, macOS 14.0 deployment target,
  `LSUIElement = YES`) and the **"Build / sign / notarize / distribute toolchain"** section
  (`xcodebuild` archive, `codesign --options runtime`, `xcrun notarytool submit --wait`,
  `xcrun stapler staple`, optional `create-dmg`). This is the authoritative how-to for Phase 0.

### Project planning
- `.planning/PROJECT.md` — vision, constraints, Key Decisions (direct notarized distribution / no
  App Store; product name TBD; native Swift).
- `.planning/REQUIREMENTS.md` — **APP-01** (menu-bar agent, no Dock, menu to open settings + quit),
  **APP-02** (launch-at-login from settings), **APP-04** (Developer-ID signed + notarized + stapled).
- `.planning/ROADMAP.md` → **§ "Phase 0"** (goal + 4 success criteria) and **§ "Phase 6"**
  (where real notarization + clean-Mac open is re-verified — the home of the deferred carry-over).

_No external ADRs/specs — requirements fully captured in CLAUDE.md + the planning docs above._
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **None** — this is a fresh repository. No Xcode project, no Swift source yet. Phase 0 creates the
  initial project from scratch.

### Established Patterns
- No code patterns yet. CLAUDE.md pre-establishes the stack conventions (SwiftUI + small AppKit
  surface, Swift 5 language mode, un-sandboxed, `SMAppService`).

### Integration Points
- None yet. Phase 0 lays the foundation (app target, Info.plist `LSUIElement`, status item,
  settings window) that Phases 1–6 build on.
</code_context>

<specifics>
## Specific Ideas

- The notarization script (D-02 / SC#4) must be a **real, commented, re-runnable shell script**,
  not ad-hoc copy-paste commands. Placeholders (e.g. `DEVELOPER_ID`, `APPLE_ID` / `TEAM_ID` /
  keychain notary profile) must be clearly marked so the user can fill them in and run the script
  **unchanged** once the Apple Developer account exists.
- The local Gatekeeper demonstration should make the contrast explicit: the un-notarized ad-hoc
  build is blocked once quarantined; document that notarization + stapling is what removes the block
  on a clean machine.
- The user is a first-time programmer — important steps (Xcode settings, what each script line does,
  how to run/test) should be explained alongside the code.
</specifics>

<deferred>
## Deferred Ideas

- **Real notarization + clean-second-Mac Gatekeeper test** (Phase 0 success criterion #3) → executed
  at **Phase 6 release**, once the Apple Developer account is purchased. This is not new scope — it's
  the Phase 0 success criterion deliberately carried forward because the paid account is deferred.

### Reviewed Todos (not folded)
(None — no pending todos existed to review.)
</deferred>

---

*Phase: 00-foundations-notarization-dry-run*
*Context gathered: 2026-06-26*
