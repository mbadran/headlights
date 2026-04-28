# Changelog

All notable changes to **headlights.nvim** are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-04-28

First release after the post-migration review pass. The Lua/Nvim port is now
hardened with a modern test framework, a CLI driver, container-based local
testing, and a documented session workflow for AI agents and humans alike.

### Added
- **Test framework** migrated to [`nvim-mini/mini.test`](https://github.com/nvim-mini/mini.test).
  Plenary's busted runner is no longer required. Trade-offs documented in
  `TESTING.md`.
- **Single-command smoke test** — `make smoke` runs one end-to-end check
  (`tests/smoke/smoke.sh`) covering install → snapshot → JSON output. The full
  suite (`make test`) still exercises every scenario.
- **CLI driver** — `bin/headlights` is a shell wrapper around `nvim -l` that
  prints the live snapshot to stdout (text / markdown / json), so CI, scripts,
  and Docker can validate output without launching a TUI.
- **Docker test environment** — `docker/Dockerfile` plus
  `scripts/docker-test.sh` build a reproducible Ubuntu 24.04 + Neovim image
  for manual or automated testing on a remote Linux host. See `TESTING.md`.
- **Session hygiene scripts**:
  - `scripts/session-start.sh` — prints the welcome status (branch, version,
    test/lint state, open issues, recent changelog entries).
  - `scripts/session-end.sh` — runs the full quality gate (smoke + tests +
    health), prints a session summary, dumps changelog tail, and prompts for
    merge/cleanup.
- **`extra_plugin_dirs` config option** (#29) — users can supply additional
  Lua-pattern roots so plugins in non-standard directories (Nix store,
  custom rtp) are grouped correctly.
- **Full attribution for functions, abbreviations, and highlights** (#25)
  — functions via `getscriptinfo().functions`; abbreviations and
  highlights via parsing the `Last set from` source path emitted by
  `:verbose abbreviate` / `:verbose highlight`.
- **Autocommand browsing** (#26) — `nvim_get_autocmds({})` is now part of
  the snapshot. Autocommands are attributed to a plugin when the augroup
  name contains the plugin's name (case-insensitive substring, longest
  match wins). Unattributed autocmds appear under a synthetic
  `·orphans (unattributed)` bundle. New `show_autocmds` config option.
- **Sign browsing** — `vim.fn.sign_getdefined()` is collected and
  attributed by sign-name / `texthl` substring match against bundle names.
  New `show_signs` config option. Unattributed signs join the orphans
  bundle.
- **`CHANGELOG.md`** — this file.
- **`VERSION`** — single-line semver string.
- **`TESTING.md`** — Docker, manual, headless, and CLI testing instructions.

### Changed
- **User-facing UI rename** (#35) — every "Bundle"/"Bundles" label in the
  popup breadcrumb, buffer header, and docs now reads "Plugin"/"Plugins".
  Internal module/variable names (`bundler.lua`, `bundle`) are unchanged on
  purpose — they stay accurate to the data model.
- **README ASCII art** — replaced the two-circle headline with an elaborate
  car-headlights illustration that casts beams into the page.
- **CI workflow** — replaced the plenary cache + invocation with a
  mini.test-based pipeline; CI now runs the smoke test first (fast fail),
  then the full suite, on Neovim stable + nightly.
- **AGENTS.md** — documents the new branch convention, session routines,
  autonomy guidelines, and updated test framework.
- **CONTRIBUTING.md** — points at mini.test, the smoke target, and the
  Docker test path.
- **`doc/headlights-nvim.txt`** — refreshed help file with new ASCII art and
  config docs for `extra_plugin_dirs`.

### Removed
- **plenary.nvim** dependency removed from CI and Makefile.
- `tests/minimal_init.lua` plenary bootstrap rewritten for mini.test.
- **`legacy/` folder** — the original Vim 7/8 + Python plugin moved to a
  dedicated `legacy` branch (formerly `master`). The default branch is now
  `main` and contains only the modern Lua codebase.

### Closed issues
- #22 — Vim 7 latex-suite hang against the legacy Python plugin
  (closed not-planned; legacy codebase now lives on the `legacy` branch).
- #25 — abbreviations / functions / highlights attribution.
- #26 — autocommand browsing.
- #28 — Telescope fuzzy-search extension (consolidated into #31).
- #29 — non-standard plugin directories — `extra_plugin_dirs` config option.
- #33 — buffer output formats (text / markdown / json) shipped in the
  initial Lua rewrite; verified during this review.
- #34 — `:Headlights {filter}` plugin name filtering shipped in the
  initial Lua rewrite; verified during this review.
- #35 — Bundles → Plugins user-facing rename.
- #36 — Vim help documentation (`doc/headlights-nvim.txt`) shipped in the
  initial Lua rewrite; minor content refresh in this release.
- #37 — elaborate ASCII-art visual identity for README + help + buffer.

[Unreleased]: https://github.com/mbadran/headlights/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/mbadran/headlights/releases/tag/v0.2.0
