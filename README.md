```
  ◉  ◉   headlights.nvim
  ─────────────────────────────────────────────────
  illuminate the footprint of your installed plugins
```

[![CI](https://github.com/mbadran/headlights/actions/workflows/ci.yml/badge.svg)](https://github.com/mbadran/headlights/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Neovim ≥ 0.9](https://img.shields.io/badge/Neovim-%3E%3D%200.9-blueviolet?logo=neovim&logoColor=white)](https://neovim.io)

---

## Why headlights?

Every plugin you install leaves a **footprint** in Neovim: new commands,
key mappings, abbreviations, functions, highlight groups, and source files.
Over time — especially with 20, 50, or 100+ plugins — that footprint becomes
impossible to keep in your head.

**headlights gives you a full audit trail**: open it and immediately see
*exactly* what every installed plugin contributes, organised by plugin.
No more grepping through `:map` or wondering where `:Git` came from.
No registration required — it inspects Neovim's own runtime state automatically.

---

## What it shows

For every loaded plugin:

| Resource | Example |
|----------|---------|
| **Commands** | `:Git`, `:Telescope`, `:TSInstall` |
| **Key mappings** | `n <leader>gs → :Gstatus<CR>` |
| **Abbreviations** | `i  teh → the` |
| **Functions** | `fugitive#Git()` |
| **Highlight groups** | `GitSignsAdd`, `TelescopePrompt` |
| **Source files** | `~/.local/share/nvim/lazy/vim-fugitive/plugin/fugitive.vim` |

All attributed to their source plugin using Neovim's native `script_id` API —
no plugin manager dependency, no configuration needed.

---

## UI modes

### Floating popup  — `:Headlights popup`

Interactive hierarchical menu. Default in GUI frontends (Neovide, nvui, …);
also works in terminal Neovim.

```
╭──────────────── headlights.nvim ───────────────╮
│   fugitive                  [15 cmds  8 maps]  │
│   telescope.nvim            [4 cmds  12 maps]  │
│   nvim-treesitter           [6 cmds]           │
│   comment.nvim              [2 cmds   4 maps]  │
╰────────────────────────────────────────────────╯
  <CR> drill in   <BS>/h back   q close
```

Drill into any plugin → pick a category → pick an item.
Selecting a command drops you to the `:` command line ready to run it.

### Buffer display  — `:Headlights buffer`

Formatted scratch buffer in a vsplit. Default in terminal Neovim.
Supports plain text, Markdown, and JSON output.

```
  ◉  ◉   headlights.nvim
  ──────────────────────────────────────────────────
  q/<Esc> Close   <CR> Execute/Open   ? Help

── fugitive ─────────────────────────────[1 script]
  Commands (15):
    :Git  :Gdiff  :Gblame  :Glog  :Gstatus  …

  Mappings (8):
    n  <leader>gs         → :Gstatus<CR>
    n  <leader>gc         → :Gcommit<CR>
```

---

## Requirements

- **Neovim ≥ 0.9**

No other dependencies. Works with any plugin manager (lazy.nvim, packer,
vim-plug, pathogen, manual `rtp`, Nix, …) or none at all — discovery uses
Neovim's own `getscriptinfo()` and keymap/command APIs.

---

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "mbadran/headlights",
  cmd  = { "Headlights", "HeadlightsPopup", "HeadlightsBuffer" },
  opts = {},   -- calls require("headlights").setup({})
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "mbadran/headlights",
  config = function() require("headlights").setup({}) end,
}
```

### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'mbadran/headlights'
```
```lua
-- init.lua
require("headlights").setup({})
```

### Manual

```bash
git clone https://github.com/mbadran/headlights \
  ~/.local/share/nvim/site/pack/plugins/start/headlights
```
```lua
require("headlights").setup({})
```

---

## Commands

| Command | Description |
|---------|-------------|
| `:Headlights` | Auto-detect UI (popup in GUI, buffer in terminal) |
| `:Headlights popup` | Force floating popup |
| `:Headlights buffer` | Force buffer (plain text) |
| `:Headlights buffer markdown` | Buffer in Markdown format |
| `:Headlights buffer json` | Buffer in JSON format |
| `:Headlights <name>` | Filter to plugins matching `name` (buffer) |
| `:Headlights fug,tele` | Filter to multiple plugins (comma or space separated) |
| `:Headlights fug json` | Filter + JSON format |
| `:HeadlightsPopup` | Alias for `:Headlights popup` |
| `:HeadlightsBuffer [fmt]` | Alias for `:Headlights buffer [fmt]` |

---

## Configuration

```lua
require("headlights").setup({
  -- Which resource types to display
  show_commands      = true,
  show_mappings      = true,
  show_abbreviations = false,
  show_functions     = false,
  show_highlights    = false,
  show_files         = false,

  -- UI
  smart_menus        = true,   -- group scripts by plugin root
  show_load_order    = false,  -- prefix names with load index
  menu_width         = 60,     -- popup width (columns)
  menu_max_height    = 25,     -- popup max height (lines)

  -- Logging & diagnostics
  log_level          = vim.log.levels.WARN,  -- DEBUG|INFO|WARN|ERROR
  log_to_file        = false,
  log_file           = nil,    -- nil → stdpath("log")/headlights.log
})
```

### Suggested keymaps

```lua
vim.keymap.set("n", "<leader>hl", "<cmd>Headlights<cr>",        { desc = "Headlights" })
vim.keymap.set("n", "<leader>hp", "<cmd>Headlights popup<cr>",  { desc = "Headlights popup" })
vim.keymap.set("n", "<leader>hb", "<cmd>Headlights buffer<cr>", { desc = "Headlights buffer" })
```

---

## Popup navigation

| Key | Action |
|-----|--------|
| `j` / `k` | Move cursor |
| `<CR>` | Select / drill in |
| `<BS>` / `h` / `←` | Go back one level |
| `q` / `<Esc>` | Close |

---

## Diagnostics

```vim
:checkhealth headlights
```

Reports version compatibility, active config, UI mode, script/command
counts, and last-run timing for each phase.

Enable verbose logging:

```lua
require("headlights").setup({
  log_level   = vim.log.levels.DEBUG,
  log_to_file = true,
})
```

Log file: `:lua print(require("headlights.log").log_file_path())`

---

## Output formats

```vim
:Headlights buffer            " plain text (default)
:Headlights buffer markdown   " GitHub-flavoured Markdown
:Headlights buffer json       " JSON — pipe to jq, feed scripts, etc.
```

JSON example:

```json
{
  "generated": "2024-01-15T10:30:00Z",
  "neovim_version": "0.10.0",
  "plugins": [
    {
      "name": "fugitive",
      "commands": [{"name": "Git", "nargs": "*", "definition": "..."}],
      "mappings": [{"mode": "n", "lhs": "<leader>gs", "rhs": "..."}]
    }
  ]
}
```

---

## How it works

1. **Snapshot** — `vim.fn.getscriptinfo()` returns every loaded script with its
   `sid`. `nvim_get_commands()` and `nvim_get_keymap()` return commands and
   mappings tagged with `script_id` / `sid`. These are all native Neovim APIs
   that work regardless of plugin manager.

2. **Attribution** — each command and mapping is linked to its source plugin
   by matching `script_id` to `sid`. No heuristics, no parsing of source files.

3. **Grouping** — scripts are clustered into plugins by detecting the
   plugin-manager root directory in the path (`plugged/`, `lazy/`, `bundle/`,
   `start/`, `opt/`).

4. **UI** — GUI frontends get an interactive floating popup; terminal Neovim
   gets a formatted scratch buffer.

---

## Known limitations & roadmap

| Gap | Tracking |
|-----|----------|
| Unloaded lazy plugins invisible | [#30](https://github.com/mbadran/headlights/issues/30) |
| Abbreviations/functions/highlights not attributed to plugins | [#25](https://github.com/mbadran/headlights/issues/25) |
| No autocommand browsing | [#26](https://github.com/mbadran/headlights/issues/26) |
| No fuzzy search | [#31](https://github.com/mbadran/headlights/issues/31) |
| Non-standard plugin dir grouping | [#29](https://github.com/mbadran/headlights/issues/29) |

See [MATRIX.md](MATRIX.md) for a full comparison with similar tools.

---

## Running tests

```bash
make test                                          # full suite
make test-file FILE=tests/headlights/bundler_spec.lua
PLENARY=/path/to/plenary.nvim make test           # custom plenary path
```

Tests include unit tests, live API tests, and integration tests that source a
real Vim script fixture to verify end-to-end plugin discovery and attribution.

CI runs on every push against Neovim **stable** and **nightly**.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Please read [AGENTS.md](AGENTS.md)
before making changes.

## License

[MIT](LICENSE) — free to use with attribution.

*Inspired by [TextMate's Bundles menu](https://macromates.com/) and 14 years
of wondering what all those plugins actually do.*
