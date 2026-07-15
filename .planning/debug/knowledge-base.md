# GSD Debug Knowledge Base

Resolved debug sessions. Used by `gsd-debugger` to surface known-pattern hypotheses at the start of new investigations.

---

## island-expand-diagonal-bounce — expand animation slides diagonally and bounces off screen edge instead of morphing
- **Date:** 2026-07-15
- **Error patterns:** matchedGeometryEffect, diagonal, bounce, morph, expand, collapsed, island, frame ordering, modifier order, size interpolation, anchor
- **Root cause:** All four `.matchedGeometryEffect(id: "island", ...)` call sites in NotchPillView.swift (collapsedIsland, blobShape, wingsShape, mediaWingsOrToast) applied `.frame(...)` BEFORE `.matchedGeometryEffect`. This is backwards per SwiftUI's actual implementation (matchedGeometryEffect is itself built from an internal frame+offset) — a local `.frame` placed before it overrides the effect's own size interpolation, breaking the size-morph portion of the transition while position/translate still partially applies, producing a diagonal slide from a stale anchor instead of a symmetric grow.
- **Fix:** Reordered all four call sites so `.matchedGeometryEffect(id: "island", in: ns)` precedes `.frame(...)`. This matches SwiftUI's documented-correct order and the file's own pre-existing doc comments, which had drifted out of sync with the actual code.
- **Files changed:** Islet/Notch/NotchPillView.swift
---

