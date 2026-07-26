---
"nosleep-cli": patch
---

Add an opt-in low-battery auto-off guardrail. `nosleep on --battery` (or `--battery=N`, 1–99) restores normal sleep early when the charge drops to/below the threshold while running on battery power, so an unplugged Mac in clamshell mode can't drain itself flat. On AC power a low reading is ignored, and without the flag behavior is unchanged.
