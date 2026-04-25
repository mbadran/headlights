# Contributing to headlights.nvim

Thank you for taking the time to contribute.

---

## Before you start

- Read **AGENTS.md** — it describes the architecture, coding conventions, and
  known gaps.
- Check open [GitHub Issues](https://github.com/mbadran/headlights/issues) so
  you don't duplicate work.
- For large changes, open an issue first to discuss the approach.

---

## Setting up a development environment

1. **Clone the repo**
   ```bash
   git clone https://github.com/mbadran/headlights
   cd headlights
   ```

2. **Add to your Neovim runtimepath** (for manual testing)
   ```lua
   -- init.lua
   vim.opt.runtimepath:prepend("/path/to/headlights")
   require("headlights").setup({ log_level = vim.log.levels.DEBUG })
   ```

3. **Install [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)**
   (the test runner)
   ```bash
   git clone --depth=1 https://github.com/nvim-lua/plenary.nvim \
     ~/.local/share/nvim/lazy/plenary.nvim
   ```

4. **Run the tests**
   ```bash
   make test
   # or a single spec file
   make test-file FILE=tests/headlights/bundler_spec.lua
   ```

---

## Workflow

1. Fork the repo and create a feature branch from `master`.
2. Make your changes (test-driven; write the spec first when possible).
3. Run `make test` and confirm all tests pass.
4. Run `:checkhealth headlights` in Neovim and confirm no errors.
5. Open a pull request against `master`.

---

## Coding standards

- **Pure Lua** — no external runtime dependencies.
- **`bundler.lua` must stay pure** — no `vim.api` calls; pass all data as
  arguments so it can be unit-tested without a running Neovim.
- **Logging** — use `require("headlights.log")` rather than `print` or
  `vim.notify` directly.
- **No default keymaps** — let users bind their own keys.
- **Tests** — every new public function needs at least one test; new
  integration behaviour needs a test in `integration_spec.lua`.
- **Cleanup** — test `after_each` blocks must undo any commands, mappings,
  or buffers created.

---

## Commit messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add autocommand browsing
fix: correct bundle root for lazy.nvim paths that contain "start"
docs: update README installation section
test: add integration test for abbreviation discovery
refactor: extract popup dimension helpers
```

---

## Reporting bugs

Open a GitHub Issue with:
- Neovim version (`nvim --version`)
- Operating system
- Plugin manager and relevant plugins
- Output of `:checkhealth headlights`
- Steps to reproduce
- Expected vs. actual behaviour

---

## License

By contributing you agree that your work will be licensed under the
[MIT License](LICENSE) that covers this project.
