# AGENTS — Developer & AI-Agent Guide for headlights.nvim

This file is the canonical reference for anyone (human or AI) working on this
codebase. Read it fully before making changes.

---

## What this project is

**headlights.nvim** is a modern Neovim Lua rewrite of the original
[headlights.vim](https://github.com/mbadran/headlights) plugin.

It is a **plugin browser**: it discovers every loaded Neovim plugin and shows
what each one contributes — commands, key mappings, abbreviations, functions,
highlight groups, and source files — organised by plugin rather than as flat
global lists.

Two display modes:
- **Floating popup** — hierarchical, interactive (Plugins → Categories → Items).
  Used automatically in GUI frontends (Neovide, nvui, …), or forced with
  `:Headlights popup`.
- **Buffer display** — formatted scratch buffer in a vsplit
  (`headlights://plugins`). Default in terminal Neovim, or forced with
  `:Headlights buffer`.

A **CLI driver** at `bin/headlights` runs the same pipeline headlessly and
writes output to stdout. CI, the smoke test, and Docker all use it.

---

## Repository layout

```
lua/headlights/
  init.lua        Public API: setup(), open()
  config.lua      Options with defaults (incl. extra_plugin_dirs)
  collector.lua   Live data snapshot from Neovim APIs
  bundler.lua     Groups scripts into bundles; attributes commands/maps via sid
  ui.lua          GUI detection + UI routing
  ui/
    popup.lua     Floating-window hierarchical menu
    buffer.lua    Scratch-buffer display (text / markdown / json)
  log.lua         Structured logging + performance timing
  health.lua      :checkhealth headlights

plugin/
  headlights.lua  Entry point: guards, version check, user commands

bin/
  headlights      Shell wrapper around `nvim -l bin/headlights.lua`
  headlights.lua  Headless entrypoint: collector → bundler → renderer → stdout

tests/
  minimal_init.lua            Bootstraps mini.test for headless test runs
  test_config.lua             Unit tests — config defaults & overrides
  test_collector.lua          Live-API tests for the collector
  test_bundler.lua            Pure-logic tests (incl. extra_plugin_dirs)
  test_ui_buffer.lua          Buffer renderer + open() tests
  test_ui_popup.lua           Popup build_menu_lines + open() tests
  test_integration.lua        Real-fixture before/after end-to-end tests
  fixtures/test_plugin.vim    Minimal fake plugin used by integration tests
  smoke/smoke.sh              Single end-to-end smoke test (bin/headlights)

docker/
  Dockerfile                  Ubuntu 24.04 + Neovim from the official tarball

scripts/
  session-start.sh            Print start-of-session status summary
  session-end.sh              Run quality gates + dump session summary
  docker-test.sh              Build image and run smoke (or any command)

doc/
  headlights-nvim.txt         Vim/Neovim help (`:help headlights`)

.github/workflows/
  ci.yml                      GitHub Actions — smoke + tests + lint
```

Top-level files: `README.md`, `CHANGELOG.md`, `VERSION`, `TESTING.md`,
`PRD.md`, `MATRIX.md`, `CONTRIBUTING.md`, `LICENSE`, `Makefile`.

---

## Architecture decisions

### Loading model — files on disk, not in-memory

The plugin is a standard Lua plugin loaded from `runtimepath` like any other.
We deliberately do **not** vendor or hot-load anything: all source lives on
disk under `lua/headlights/` and `plugin/headlights.lua`. This is what plugin
managers (lazy.nvim, packer, vim-plug, pathogen) and Neovim's runtime model
expect. The CLI driver and tests use the same on-disk runtimepath, just
prepended via `--cmd 'set rtp+=…'` or `vim.opt.runtimepath:prepend(…)` so
nothing is special-cased.

### Lazy loading

`plugin/headlights.lua` is intentionally tiny: it guards for Neovim ≥ 0.9,
defines `:Headlights` and aliases, and exits. The heavy modules (`collector`,
`bundler`, `ui/*`) are only `require()`-d when a command runs. This means
the plugin can be safely listed under `cmd = { "Headlights" }` in lazy.nvim
without paying any startup cost.

### Data flow

```
:Headlights
  → init.open()
      → log.time("snapshot", collector.snapshot)
          collector queries: getscriptinfo(), nvim_get_commands(),
                             nvim_get_keymap(mode×8), execute('abbreviate'),
                             execute('function'), execute('highlight')
      → log.time("build_bundles", bundler.build_bundles)
          scripts grouped by plugin-manager root directory
          commands linked to bundles via cmd.script_id == script.sid
          mappings linked via map.sid == script.sid
          functions linked via getscriptinfo().functions  (#25, partial)
      → log.time("ui.open", ui.open)
          ui.is_gui() → popup.open()  OR  buffer.open()
```

### Key invariant: `script_id` / `sid` linkage

Neovim 0.9+ exposes `script_id` on commands and `sid` on mappings, both
matching the `sid` field in `getscriptinfo()`. This is how we attribute
resources to their source plugin without any user registration.

Functions are attributed via `getscriptinfo().functions` (the per-script
list of global function names). Abbreviations and highlight groups are
attributed by parsing the `Last set from` line emitted by
`:verbose abbreviate` / `:verbose highlight` and matching against bundle
roots (longest-prefix wins).

Autocommands and signs lack a script_id field, so attribution is heuristic:
the augroup name (or sign name + texthl) is matched against bundle names
(case-insensitive substring, longest match wins). Anything unattributed
appears under a synthetic `·orphans (unattributed)` bundle so it isn't
silently dropped.

### `bundler.bundle_root_from_path()`

Recognises these plugin-manager parent directories by default:
`plugged` (vim-plug), `bundle` (pathogen), `lazy` (lazy.nvim),
`start` and `opt` (vim pack / packer.nvim).

Falls back to "two directories above the file" for unrecognised paths
(e.g. standard Neovim runtime).

For non-standard layouts (Nix store, custom rtp dirs), users can supply
extra Lua patterns via `config.extra_plugin_dirs`. User patterns are tried
**before** the built-in patterns so they take precedence over the generic
fallback.

### GUI detection

`ui.is_gui()` checks `vim.fn.has('gui_running')` and well-known frontend
variables (`vim.g.neovide`, `vim.g.nvui`, `vim.g.gonvim_running`,
`vim.g.neoray`, `vim.g.GuiLoaded`). Add new frontends here.

### Why mini.test (not plenary)

We migrated off `nvim-lua/plenary.nvim`'s busted runner in v0.2.0:
plenary's runner is in maintenance mode, broader than we need, and the
community's test ergonomics have moved on.
[`nvim-mini/mini.test`](https://github.com/nvim-mini/mini.test) is the
modern, well-maintained alternative; it ships first-class child-process
helpers and screen tests we'll use later.

Trade-offs and migration notes are documented in [TESTING.md](TESTING.md)
section 6.

---

## Branches

- **`main`** — default branch; modern Neovim Lua rewrite. All new work
  lands here.
- **`legacy`** — the original Vim 7/8 + Python plugin (formerly `master`),
  kept frozen for reference. **Do not push to it.**
- **`claude/<topic>`** — short-lived working branches for AI-agent or
  human contributors. Branch from `main`, PR back into `main`.
- **`gh-pages`** — old project page; left alone.

The active working branch for this session is
`claude/review-lua-migration-0eoF6`. **Never push directly to `main` or
`legacy`.** When a session is finished and the operator approves a merge,
open a PR against `main`.

---

## Session routines (for AI agents and humans)

Both routines are scripts. Run them; don't reinvent them.

### Start of every session — `scripts/session-start.sh`

Prints a status summary so you know where you are before touching anything:

```
make session-start
# or
scripts/session-start.sh
```

Includes: branch, upstream sync state, working-tree dirtiness, current
`VERSION`, last 5 commits, latest `CHANGELOG.md` entry, available quality
gates, and (if `gh` is authed) the top open issues.

### End of every session — `scripts/session-end.sh`

Runs the canonical quality gate, prints a session summary, dumps the latest
changelog entry, and shows the operator's next steps:

```
make session-end
# or
scripts/session-end.sh           # full gates (smoke + tests + changelog)
scripts/session-end.sh --quick   # smoke only, skip full suite
scripts/session-end.sh --skip-tests  # summary only
```

Exit codes:
- `0` — all gates passed
- `1` — smoke test failed
- `2` — full test suite failed
- `3` — changelog hygiene failed (Unreleased empty while git is dirty)

### Quality gates

| Gate                | Command                       |
|---------------------|-------------------------------|
| Smoke (fast)        | `make smoke`                  |
| Full mini.test      | `make test`                   |
| One spec file       | `make test-file F=tests/test_<x>.lua` |
| Lint                | `make lint`                   |
| Docker smoke        | `make docker-test`            |
| Health              | `:checkhealth headlights`     |

See [TESTING.md](TESTING.md) for the long form.

---

## Autonomy guidelines for AI agents

The operator wants to be a minimal bottleneck. Defaults:

1. **Ask only at the *start* of a session** if you genuinely need clarity.
   Use the question tool sparingly; bundle multiple questions into one prompt.
2. **Don't ask mid-session** unless you are actually blocked or about to do
   something with significant blast radius (`git reset --hard`, `git push
   --force`, deleting files outside the changeset, modifying CI secrets,
   merging PRs, etc.).
3. **Never silently guess** when missing information would change the
   outcome — pause and ask.
4. **Maintain `CHANGELOG.md`** as you go, under `[Unreleased]`. The
   session-end script will warn if the section is empty when there are
   pending changes.
5. **Keep edits scoped** — don't refactor unrelated code while you're
   "in the area".
6. **Use the session-start and session-end scripts** as your bookends.
   They are the audit trail.
7. **Never push to `main` or `legacy`.** Develop on the agreed
   `claude/<topic>` branch, push there, and let the operator merge.
8. **Plan, then execute.** Use TodoWrite for any work spanning more than
   a couple of files; mark items completed as you go.
9. **Trust the tests.** If `make test` fails after a change, fix the
   change — don't disable the test.

---

## Running tests

Requires Neovim ≥ 0.9 and [`nvim-mini/mini.test`](https://github.com/nvim-mini/mini.test).

```bash
make smoke                                 # single end-to-end smoke
make test                                  # full mini.test suite
make test-file F=tests/test_bundler.lua    # one spec file
MINI_TEST=/path/to/checkout make test      # override mini.test location
make docker-test                           # everything inside Ubuntu 24.04
```

CI runs automatically on push via `.github/workflows/ci.yml` against
`stable` and `nightly` Neovim.

### Integration tests

`tests/test_integration.lua` sources `tests/fixtures/test_plugin.vim`
(a minimal fake plugin) and verifies end-to-end discovery, attribution,
and UI rendering. This is the closest thing to a "before plugin installed
/ after plugin installed" scenario at the unit level.

`tests/smoke/smoke.sh` is the **single-command** smoke test: it boots
Neovim from a clean state, runs `bin/headlights --format=json`, and
checks that the output is well-formed JSON with a non-empty plugins
array. It is the one thing CI runs first; if it fails, the rest of the
suite is skipped.

---

## Coding conventions

- Pure Lua; no external dependencies beyond Neovim ≥ 0.9 itself.
- `lua/headlights/bundler.lua` — keep pure (no `vim.api` calls) so it is
  unit-testable with injected data.
- Use `log.time(label, fn)` around any operation that might be slow.
- Use `log.warn()` / `log.error()` for user-visible problems; `log.debug()`
  for verbose internals.
- All user commands are created in `plugin/headlights.lua`, not in `init.lua`.
- Do not add default keymaps; users should set their own (document them in README).
- Tests use mini.test idioms: a file `return`s a `MiniTest.new_set()` whose
  test cases are functions assigned to string keys.
- Clean up after tests: delete any commands, mappings, or buffers created.

---

## Known gaps / planned work

See GitHub issues for the canonical list. Current major gaps:

| Gap | Notes |
|-----|-------|
| Lazy-loaded plugins invisible until loaded | Need to read lazy.nvim metadata (#30) |
| Plugin version/metadata not shown | No standard Neovim API for this (#32) |
| No fuzzy search | Telescope/fzf-lua/mini.pick extension planned (#31) |
| Tree-sitter parsers / LSP clients / DAP / diagnostic sources | Tracked as v2 in PRD |
| Digraphs | Rare; tracked as a low-priority follow-up |

---

## Checklist before opening a PR

1. `scripts/session-end.sh` exits 0 (covers smoke + tests + changelog).
2. New behaviour has test coverage (unit, integration, or smoke).
3. `:checkhealth headlights` shows no errors on a manual local run.
4. Any new config option documented in `README.md`, `config.lua`,
   and `doc/headlights-nvim.txt`.
5. `CHANGELOG.md` updated under `[Unreleased]`.
6. `AGENTS.md` updated if architecture / conventions changed.
