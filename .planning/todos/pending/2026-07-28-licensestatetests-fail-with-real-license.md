---
created: 2026-07-28T22:41:00.000Z
title: LicenseStateTests fail when a real license is present in Keychain
area: licensing
files:
  - IsletTests/LicenseStateTests.swift
---

## Problem

Found incidentally during a full Cmd-U run (2026-07-28) while confirming Phase 27's
verification checkpoints for v1.4's close-out — unrelated to Phase 27 itself. 4 tests failed,
all expecting a trial-state result but getting `"licensed"` instead:

- `testActiveTrialReturnsDaysRemaining`
- `testExpiredTrialReturnsTrialExpired`
- `testIsEntitledMapping`
- `testMissingTrialStartDateFallsBackToFreshTrial`

Looks like a test-isolation issue rather than a code regression: this machine's real Keychain
now has an actual purchased/activated Islet license (from the developer's own daily use), and
whatever these tests read to determine license status appears to hit the real Keychain instead
of an injected/fake store, so it always resolves to "licensed" regardless of the trial dates the
test tries to set up.

## Solution

TBD — needs a `/gsd-debug` session to confirm whether `LicenseStateTests` genuinely reads the
real system Keychain (test-isolation bug, needs a fake/injectable store) or whether there's an
actual precedence-logic regression in how licensed-vs-trial state is resolved.
