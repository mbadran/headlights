# Product Requirements Document — headlights.nvim

## Problem statement

Neovim's plugin ecosystem is vast.  After installing a dozen plugins, most
users can no longer recall which plugin provides which `:command`, which
`<leader>` mapping, or which filetype abbreviation.  The built-in
`:command`, `:map`, `:function`, etc. outputs are unsorted flat lists with no
attribution — they tell you *what* exists but not *where it came from*.

Existing tools (which-key, Telescope pickers) partially address discoverability
but show resources as flat, plugin-agnostic lists.  None organise resources
*by their source plugin*.

## Goals

1. **Discovery** — let users instantly see what every installed plugin
   contributes, without memorising anything.
2. **Attribution** — every command, mapping, and resource is shown under the
   plugin that defined it.
3. **Dual UI** — floating popup for interactive navigation; buffer display for
   reading and copying.
4. **Zero friction** — no explicit registration; the plugin inspects Neovim's
   own runtime state automatically.
5. **Correctness** — resources are linked to bundles via `script_id`/`sid`,
   the same mechanism Neovim uses internally.
6. **Observability** — structured logging and `:checkhealth` so users can
   diagnose problems themselves.

## Non-goals

- Not a plugin manager (use lazy.nvim, packer, vim-plug).
- Not a key-mapping editor (use which-key's `desc` integration).
- Not a fuzzy finder (Telescope extension is a future roadmap item).
- Not backwards-compatible with Vim 7/8 (Neovim ≥ 0.9 only for the Lua
  version; the original Python-based plugin still works on Vim).

## User personas

**The Explorer** — recently installed several plugins and wants to know what
keybindings each one added.  Opens `:Headlights`, navigates to the plugin,
selects Mappings.

**The Debugger** — something is shadowing a mapping.  Opens `:Headlights`,
searches the relevant bundle's Mappings to confirm where the conflict originates.

**The Documenter** — writing a cheatsheet for their team.  Opens
`:Headlights buffer`, copies the formatted output.

**The Plugin Author** — wants to confirm their plugin's commands and mappings
are properly attributed.  Uses `:Headlights` + `:checkhealth headlights`.

## Feature requirements

### Must have (v1.0)

| ID | Feature |
|----|---------|
| F-01 | Discover loaded scripts via `getscriptinfo()` |
| F-02 | Group scripts into per-plugin bundles by root directory |
| F-03 | Attribute global commands to bundles via `script_id` |
| F-04 | Attribute key mappings (all 8 modes) to bundles via `sid` |
| F-05 | Display buffer-local commands and mappings in a `·buffer` bundle |
| F-06 | Floating popup with 3-level navigation (bundles → categories → items) |
| F-07 | Buffer display (`headlights://bundles`) in a vsplit |
| F-08 | Auto-detect GUI vs terminal to choose default UI |
| F-09 | Force UI mode via `:Headlights popup` / `:Headlights buffer` |
| F-10 | Configurable via `require("headlights").setup({})` |
| F-11 | `:checkhealth headlights` health report |
| F-12 | Structured logging with level control and optional file output |
| F-13 | Performance timing for each phase (snapshot, build, UI open) |

### Should have (v1.x)

| ID | Feature |
|----|---------|
| F-14 | Attribute abbreviations, functions, highlights to bundles |
| F-15 | Autocommand browsing (`nvim_get_autocmds`) |
| F-16 | Lazy-loaded plugin metadata visible before loading |
| F-17 | Plugin version / author metadata |
| F-18 | Telescope extension for fuzzy search across bundles |

### Nice to have (v2+)

| ID | Feature |
|----|---------|
| F-19 | Tree-sitter parser list |
| F-20 | LSP client information |
| F-21 | Diagnostic source listing |
| F-22 | DAP configuration browsing |
| F-23 | Spillover grouping for large plugin counts (A–I, J–R, S–Z) |

## Success metrics

- `:Headlights` opens in < 200 ms on a typical setup (50 plugins).
- All commands from a test-fixture plugin appear attributed to the correct
  bundle (integration test coverage).
- Zero unhandled errors during normal operation (error-logged, user-notified).
- `:checkhealth headlights` shows all green on Neovim ≥ 0.9.

## Constraints

- Neovim ≥ 0.9 (required for `getscriptinfo`, `nvim_open_win` border titles).
- No mandatory external dependencies; optional Telescope extension can be separate.
- MIT license; free to use with attribution.

## Roadmap snapshot

| Milestone | Target content |
|-----------|---------------|
| v0.1 | F-01 through F-13 — initial Lua rewrite |
| v0.2 (current) | Test-framework migration to mini.test, CLI driver, Docker test env, F-14 (full abbrev/function/highlight attribution), F-15 (autocommand browsing), sign browsing, `extra_plugin_dirs`, "Plugins" UX rename, session routines |
| v0.3 | F-16 (lazy-aware) |
| v0.4 | F-17 (plugin metadata), F-18 (Telescope / fzf-lua / mini.pick fuzzy search) |
| v1.0 | Stable API, complete docs, full test suite |
