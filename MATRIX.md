# Competitive Matrix — headlights.nvim

This document compares headlights.nvim with similar tools in the Vim/Neovim ecosystem.
It informs our roadmap and helps users choose the right tool.

Legend: ✅ supported · 🔶 partial / requires config · ❌ not supported · 🗓 planned

---

## Feature comparison

| Feature | **headlights.nvim** | which-key.nvim | Telescope (built-ins) | lazy.nvim UI | legendary.nvim | nvim-mapper |
|---------|:-------------------:|:--------------:|:---------------------:|:------------:|:--------------:|:-----------:|
| **Organisation** |
| Resources grouped *by source plugin* | ✅ | ❌ | ❌ | 🔶 (load status only) | ❌ | ❌ |
| Automatic discovery (no registration) | ✅ | ✅ | ✅ | ✅ | ❌ (must register) | ❌ (must register) |
| **Resource types** |
| Commands | ✅ | ❌ | ✅ (flat) | ❌ | ✅ | ❌ |
| Key mappings (all modes) | ✅ | ✅ | ✅ (flat) | ❌ | ✅ | ✅ |
| Abbreviations | ✅ (collected) | ❌ | ❌ | ❌ | ❌ | ❌ |
| Functions | ✅ (collected) | ❌ | ❌ | ❌ | ❌ | ❌ |
| Highlight groups | ✅ (collected) | ❌ | ✅ | ❌ | ❌ | ❌ |
| Autocommands | 🗓 v0.2 | ❌ | ✅ (flat) | ❌ | ✅ | ❌ |
| Source file list | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Plugin load times | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Plugin version / author | 🗓 v0.3 | ❌ | ❌ | ✅ | ❌ | ❌ |
| LSP clients | 🗓 v2 | ❌ | ✅ | ❌ | ❌ | ❌ |
| Tree-sitter parsers | 🗓 v2 | ❌ | ✅ | ❌ | ❌ | ❌ |
| **UI** |
| Floating popup | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Persistent buffer display | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Hierarchical drill-down | ✅ | ✅ (by prefix) | ❌ | ✅ | ❌ | ❌ |
| Fuzzy search | 🗓 v0.4 | ✅ | ✅ | ✅ | ✅ | ✅ |
| Execute command from UI | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Open source file from UI | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ |
| **Integration** |
| Telescope extension | 🗓 v0.4 | native | native | native | ✅ | ✅ |
| fzf-lua support | 🗓 | ❌ | ❌ | 🔶 | ✅ | ❌ |
| **Health & observability** |
| `:checkhealth` integration | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Structured logging | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Performance profiling | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ |
| **Platform** |
| Neovim terminal | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Neovim GUI (Neovide etc.) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Vim 7/8 (legacy) | 🔶 (original plugin) | ❌ | ❌ | ❌ | ❌ | ❌ |
| No external Lua dependencies | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Dev experience** |
| Test suite | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| CI (GitHub Actions) | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| MIT license | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## Tool summaries

### [which-key.nvim](https://github.com/folke/which-key.nvim)
The de-facto standard for mapping discovery. Shows a popup of available keys
after a prefix, organised by key sequence, not by plugin. Excellent UX for
navigating keybindings; does not show commands, abbreviations, or functions, and
doesn't attribute resources to their plugin.

### [Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) built-ins
`:Telescope keymaps`, `:Telescope commands`, `:Telescope help_tags` etc. are
flat fuzzy-searchable lists. Powerful for finding anything; does not group by
plugin or show multiple resource types together.

### [lazy.nvim](https://github.com/folke/lazy.nvim) built-in UI
Shows all installed plugins with load status, load times, and repo metadata.
Does not expose what each plugin *contributes* (commands, mappings, etc.).

### [legendary.nvim](https://github.com/mrjones2014/legendary.nvim)
A command palette that aggregates commands, keymaps, autocmds, and functions
into a searchable list. Powerful but requires explicit registration of items;
not automatic.

### [nvim-mapper](https://github.com/lazytanuki/nvim-mapper)
Wraps `vim.keymap.set` to add descriptions; shows them via Telescope. Mappings
only, and requires opting in per mapping.

### [Original headlights.vim](https://github.com/mbadran/headlights) (Vim 7/8)
The predecessor to this project. Inspired by TextMate's Bundles menu. Used
Python for data parsing and Vim's native `:menu` system for display. Works on
Vim 7/8 with Python 2.6+. No interactive navigation; menus appear in the GUI
menu bar only.

---

## Unique value of headlights.nvim

1. **Per-plugin organisation** — the only tool that groups *all* resource types
   under their source plugin automatically.
2. **Multi-category** — commands + mappings + abbreviations + functions +
   highlights + files in one browser.
3. **Zero registration** — works immediately after install, no configuration
   of individual resources required.
4. **Dual UI** — popup *and* buffer, depending on context.
5. **Observability** — logging, profiling, and `:checkhealth` built in.

---

## Roadmap items suggested by this analysis

| Priority | Feature | Rationale |
|----------|---------|-----------|
| High | Fuzzy search (Telescope extension) | All major competitors have it |
| High | Abbreviation / function attribution | Collected but not yet linked to bundles |
| Medium | Autocommand browsing | legendary.nvim advantage; useful for debugging |
| Medium | Lazy-loaded plugin awareness | lazy.nvim advantage |
| Low | Plugin metadata (version, author) | lazy.nvim advantage |
| Low | LSP / Tree-sitter info | telescope advantage |
