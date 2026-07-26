# nosleep-cli

## 0.1.0

### Minor Changes

- [#5](https://github.com/omsimos/nosleep/pull/5) [`235f089`](https://github.com/omsimos/nosleep/commit/235f0896722f7e5e03f0b8c77b0a850ef8e46bac) Thanks [@hyamero](https://github.com/hyamero)! - Restore sleep early when the battery runs low. `nosleep on` now also auto-offs at 20% charge while running on battery power, so an unplugged Mac in clamshell mode can't drain itself flat waiting out the window. On AC power a low reading is ignored, and a Mac with no battery skips the guardrail. Use `--battery=N` (1–99) to move the threshold, or `--no-battery` for the previous time-only behavior.

## 0.0.2

### Patch Changes

- [`7b2bf98`](https://github.com/omsimos/nosleep/commit/7b2bf98777ae374b088a3fdd9a5c7c57faa29e0f) Thanks [@Blankeos](https://github.com/Blankeos)! - Ship the bundled brightness helper with the npm package and Homebrew formula.

- [`1536419`](https://github.com/omsimos/nosleep/commit/1536419c52ea30be8c398a1c2e9627a6d7275d2d) Thanks [@Blankeos](https://github.com/Blankeos)! - feat(release): ship nosleep-brightness in package and Homebrew artifacts

## 0.0.1

### Patch Changes

- [`00065e0`](https://github.com/omsimos/nosleep/commit/00065e065935223c07dacd2843782d8924b498a8) Thanks [@Blankeos](https://github.com/Blankeos)! - Add npm and Homebrew installation, plus automated GitHub Releases.
