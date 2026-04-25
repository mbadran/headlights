# headlights.nvim

A plugin browser for Neovim — discover what every loaded plugin contributes,
organised *by plugin*.

Inspired by TextMate's Bundles menu and the original
[headlights.vim](https://github.com/mbadran/headlights).

---

## What it does

`:Headlights` opens a browser showing every loaded Neovim plugin alongside
the resources it defines:

- **Commands** (`:Git`, `:Telescope`, …)
- **Key mappings** (all modes)
- **Abbreviations**
- **Functions**
- **Highlight groups**
- **Source files**

Resources are attributed to their bundle automatically using Neovim's internal
`script_id` — no registration required.

---

## UI modes

### Floating popup (GUI or explicit request)

Used by default in GUI frontends (Neovide, nvui, nvim-qt, …) or when you run
`:Headlights popup`.

```
╭──────────────── Headlights ─────────────────╮
│   fugitive                  [15 cmds  8 maps]│
│   telescope.nvim            [4 cmds  12 maps]│
│   nvim-treesitter           [6 cmds]         │
│   comment.nvim              [2 cmds   4 maps]│
│   …                                          │
╰─────────────────────────────────────────────╯
  <CR> open   <BS>/h go back   q close
```

Press `<CR>` to drill into a bundle → pick a category → pick an item.
Selecting a command drops you at the `:` command line ready to run it.

> **Terminal users**: floating windows work in terminal Neovim too.
> `:Headlights popup` gives you the interactive popup even without a GUI.

### Buffer display (terminal default or explicit request)

Used by default in terminal Neovim, or with `:Headlights buffer`.

Opens `headlights://bundles` in a vertical split:

```
Headlights – Plugin Browser
────────────────────────────────────────
  q/<Esc> Close   <CR> Execute/Open   ? Help

── fugitive ─────────────────────[1 script]
  Commands (15):
    :Git  :Gdiff  :Gblame  :Glog  :Gstatus  …

  Mappings (8):
    n  <leader>gs         → :Gstatus<CR>
    n  <leader>gc         → :Gcommit<CR>

── telescope.nvim ───────────────[1 script]
  Commands (4):
    :Telescope  :TelescopeBuiltin  …
```

Press `<CR>` on a command line to execute it; on a file path to open it.

---

## Requirements

- **Neovim ≥ 0.9** (uses `getscriptinfo()` and floating-window border titles)

---

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "mbadran/headlights",
  cmd = { "Headlights", "HeadlightsPopup", "HeadlightsBuffer" },
  opts = {
    -- defaults shown; omit unchanged keys
    show_commands      = true,
    show_mappings      = true,
    show_abbreviations = false,
    show_functions     = false,
    show_highlights    = false,
    show_files         = false,
  },
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "mbadran/headlights",
  config = function()
    require("headlights").setup({})
  end
}
```

### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'mbadran/headlights'
```

Then in `init.lua`:
```lua
require("headlights").setup({})
```

### Manual (no plugin manager)

```bash
git clone https://github.com/mbadran/headlights \
  ~/.local/share/nvim/site/pack/manual/start/headlights
```

```lua
-- init.lua
require("headlights").setup({})
```

---

## Commands

| Command | Description |
|---------|-------------|
| `:Headlights` | Open in auto-detected mode (popup in GUI, buffer in terminal) |
| `:Headlights popup` | Force floating popup (works in terminal too) |
| `:Headlights buffer` | Force buffer display |
| `:HeadlightsPopup` | Alias for `:Headlights popup` |
| `:HeadlightsBuffer` | Alias for `:Headlights buffer` |

---

## Configuration

All options and their defaults:

```lua
require("headlights").setup({
  -- Which resource types to display
  show_commands      = true,   -- plugin-defined :Commands
  show_mappings      = true,   -- key mappings in all modes
  show_abbreviations = false,  -- text abbreviations
  show_functions     = false,  -- global Vim functions
  show_highlights    = false,  -- custom highlight groups
  show_files         = false,  -- source script paths

  -- Menu appearance
  smart_menus        = true,   -- group scripts by plugin root directory
  show_load_order    = false,  -- prefix bundle names with load order index
  menu_width         = 60,     -- floating popup width (columns)
  menu_max_height    = 25,     -- floating popup max height (lines)

  -- Logging & diagnostics
  log_level          = vim.log.levels.WARN,  -- DEBUG | INFO | WARN | ERROR
  log_to_file        = false,                -- write logs to disk
  log_file           = nil,                  -- nil → stdpath("log")/headlights.log
})
```

### Suggested keymaps

headlights.nvim ships with no default keymaps; add your own:

```lua
vim.keymap.set("n", "<leader>hl", "<cmd>Headlights<cr>",       { desc = "Headlights browser" })
vim.keymap.set("n", "<leader>hp", "<cmd>Headlights popup<cr>", { desc = "Headlights popup" })
vim.keymap.set("n", "<leader>hb", "<cmd>Headlights buffer<cr>",{ desc = "Headlights buffer" })
```

---

## Popup navigation

| Key | Action |
|-----|--------|
| `j` / `k` | Move cursor |
| `<CR>` | Select / drill down |
| `<BS>` / `h` / `←` | Go back one level |
| `q` / `<Esc>` | Close |

Selecting a **command** closes the popup and puts `:CommandName ` in the
command line, ready to run.  Selecting a **file** opens it in the current
window.  Selecting **Help** runs `:help <plugin-name>`.

---

## Diagnostics

```vim
:checkhealth headlights
```

Reports:
- Neovim version compatibility
- Number of scripts and commands visible
- Last-run performance timings (after `:Headlights` runs once)
- Active configuration

Enable debug logging to trace every step:

```lua
require("headlights").setup({
  log_level   = vim.log.levels.DEBUG,
  log_to_file = true,
})
```

Log file location: `:lua print(require("headlights.log").log_file_path())`

---

## Running the tests

Requires [plenary.nvim](https://github.com/nvim-lua/plenary.nvim):

```bash
# Full suite
make test

# Single spec file
make test-file FILE=tests/headlights/bundler_spec.lua

# Override plenary location
PLENARY=/path/to/plenary.nvim make test
```

Tests include unit tests (pure logic, no Neovim API), live API tests
(collector queries on the running Neovim process), and integration tests
that source a real Vim script fixture and verify end-to-end attribution.

CI runs on every push via GitHub Actions against Neovim stable and nightly.

---

## How it works

1. **Snapshot** — `getscriptinfo()` returns every loaded script with its
   `sid` (script ID). `nvim_get_commands()` and `nvim_get_keymap()` return
   commands and mappings tagged with `script_id` / `sid`.

2. **Bundle grouping** — scripts are grouped by their plugin root directory
   (detected from known plugin-manager parent directories: `plugged`, `lazy`,
   `bundle`, `start`, `opt`).

3. **Attribution** — commands are linked to their bundle by matching
   `cmd.script_id` to `script.sid`. Mappings are linked via `map.sid`.

4. **UI** — GUI frontends get an interactive floating popup; terminal Neovim
   gets a formatted scratch buffer.

---

## Known limitations

- Abbreviations, functions, and highlight groups are **collected** but not yet
  attributed to individual bundles (Neovim doesn't expose `script_id` for
  these — see [open issues](https://github.com/mbadran/headlights/issues)).
- Lazy-loaded plugins that haven't been triggered yet won't appear.
- Autocommands are not yet browsed.

See [MATRIX.md](MATRIX.md) for a full comparison with similar tools and
[PRD.md](PRD.md) for the roadmap.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE) — free to use with attribution.
