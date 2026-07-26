---
"nosleep-cli": patch
---

Restore sleep early when the battery runs low. `nosleep on` now also auto-offs at 20% charge while running on battery power, so an unplugged Mac in clamshell mode can't drain itself flat waiting out the window. On AC power a low reading is ignored, and a Mac with no battery skips the guardrail. Use `--battery=N` (1–99) to move the threshold, or `--no-battery` for the previous time-only behavior.
