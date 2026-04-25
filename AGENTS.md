# AGENTS — Developer & AI-Agent Guide for headlights.nvim

This file is the canonical reference for anyone (human or AI) working on this codebase.
Read it fully before making changes.

---

## What this project is

**headlights.nvim** is a modern Neovim Lua rewrite of the original
[headlights.vim](https://github.com/mbadran/headlights) plugin.

It is a **plugin browser**: it discovers every loaded Neovim plugin and shows
what each one contributes — commands, key mappings, abbreviations, functions,
highlight groups, and source files — organised by plugin rather than as flat
global lists.

Two display modes:
- **Floating popup** — hierarchical, interactive (Bundles → Categories → Items).
  Used automatically in GUI frontends (Neovide, nvui, …), or forced with
  `:Headlights popup`.
- **Buffer display** — formatted scratch buffer in a vsplit (`headlights://bundles`).
  Default in terminal Neovim, or forced with `:Headlights buffer`.

---

## Repository layout

```
lua/headlights/
  init.lua        Public API: setup(), open()
  config.lua      Options with defaults
  collector.lua   Live data snapshot from Neovim APIs
  bundler.lua     Groups scripts into bundles; attributes commands/maps via sid
  ui.lua          GUI detection + UI routing
  ui/
    popup.lua     Floating-window hierarchical menu
    buffer.lua    Scratch-buffer display
  log.lua         Structured logging + performance timing
  health.lua      :checkhealth headlights

plugin/
  headlights.lua  Entry point: guards, version check, user commands
  headlights.vim  Legacy Vim7 plugin (kept for reference; not loaded by Lua)
  headlights.py   Legacy Python helper (kept for reference; not loaded by Lua)

tests/
  minimal_init.lua         Bootstraps plenary for headless test runs
  headlights/
    config_spec.lua        Unit tests for config module
    collector_spec.lua     Live API tests for collector
    bundler_spec.lua       Pure-logic tests for bundler path parsing & grouping
    integration_spec.lua   Before/after fixture tests (real script sourcing)
    ui/
      buffer_spec.lua      Buffer render + open() tests
      popup_spec.lua       Popup build_menu_lines + open() tests
  fixtures/
    test_plugin.vim        Minimal fake plugin sourced by integration tests

doc/
  headlights.txt  Legacy Vim help (update or replace for Neovim version)

.github/workflows/
  ci.yml          GitHub Actions: tests on stable + nightly Neovim
```

---

## Architecture decisions

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
      → log.time("ui.open", ui.open)
          ui.is_gui() → popup.open()  OR  buffer.open()
```

### Key invariant: `script_id` / `sid` linkage

Neovim 0.9+ exposes `script_id` on commands and `sid` on mappings, both
matching the `sid` field in `getscriptinfo()`. This is how we attribute
resources to their source plugin without any user registration.

Abbreviations, functions, and highlight groups do **not** carry `script_id`;
attribution for these is a planned enhancement (see GitHub issues).

### `bundler.bundle_root_from_path()`

Recognises these plugin-manager parent directories:
`plugged` (vim-plug), `bundle` (pathogen), `lazy` (lazy.nvim),
`start` and `opt` (vim pack / packer.nvim).

Falls back to "two directories above the file" for unrecognised paths
(e.g. standard Neovim runtime).

### GUI detection

`ui.is_gui()` checks `vim.fn.has('gui_running')` and well-known frontend
variables (`vim.g.neovide`, `vim.g.nvui`, `vim.g.gonvim_running`,
`vim.g.neoray`, `vim.g.GuiLoaded`). Add new frontends here.

---

## Development branch

Always develop on `claude/neovim-lua-plugin-urxoy` (or a branch from it).
Never push directly to `master`.

---

## Running tests

Requires Neovim ≥ 0.9 and [plenary.nvim](https://github.com/nvim-lua/plenary.nvim).

```bash
# Full suite
make test

# Single file
make test-file FILE=tests/headlights/bundler_spec.lua

# Override plenary path
PLENARY=/path/to/plenary.nvim make test
```

CI runs automatically on push via `.github/workflows/ci.yml` against
`stable` and `nightly` Neovim.

### Integration tests

`tests/headlights/integration_spec.lua` sources
`tests/fixtures/test_plugin.vim` (a minimal fake plugin) and verifies
end-to-end discovery, attribution, and UI rendering.  This is the closest
thing to a "before plugin installed / after plugin installed" scenario.

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
- Tests use plenary's busted-style `describe/it/before_each/after_each`.
- Clean up after tests: delete any commands, mappings, or buffers created.

---

## Known gaps / planned work

See GitHub issues for the canonical list. Current major gaps:

| Gap | Notes |
|-----|-------|
| Abbreviations/functions/highlights not attributed to bundles | No `script_id` in the Neovim API for these |
| Autocommands not browsed | `nvim_get_autocmds({})` — not yet wired in |
| Lazy-loaded plugins invisible until loaded | Need to read lazy.nvim metadata |
| Plugin version/metadata not shown | No standard Neovim API for this |
| No fuzzy search | Telescope extension planned |
| Tree-sitter parsers / LSP clients not shown | Neovim-specific gap |

---

## Checklist before opening a PR

1. `make test` passes on your local Neovim.
2. New behaviour has test coverage (unit or integration).
3. `:checkhealth headlights` shows no errors.
4. Any new config option documented in `README.md` and `config.lua`.
5. AGENTS.md updated if architecture changes.
