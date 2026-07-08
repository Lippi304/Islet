---
quick_id: 260708-ol8
status: complete
---

# Quick Task 260708-ol8: Bump MARKETING_VERSION to 1.0 for public launch

`MARKETING_VERSION` in `project.yml` bumped from `0.1` to `1.0` per the existing D-14 decision ("1.0 reserved for public launch") — this is that launch. `xcodegen generate` re-ran to regenerate `Islet.xcodeproj` from the updated config. `CFBundleShortVersionString` will read `1.0` in the next release build.
