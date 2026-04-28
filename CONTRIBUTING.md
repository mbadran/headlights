# Contributing to headlights.nvim

Thank you for taking the time to contribute.

---

## Before you start

- Read **AGENTS.md** — it describes the architecture, coding conventions,
  session routines, and known gaps.
- Read **TESTING.md** for the testing model (mini.test, smoke, Docker).
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

3. **Install [mini.test](https://github.com/nvim-mini/mini.test)** (the test
   framework). The Makefile clones it into `tests/.deps/mini.test` for you:
   ```bash
   make test-deps
   ```
   Or set `MINI_TEST=/path/to/local/checkout` to use an existing clone.

4. **Run the tests**
   ```bash
   make smoke                              # single end-to-end check
   make test                               # full suite
   make test-file F=tests/test_bundler.lua # one spec
   make docker-test                        # everything inside Ubuntu 24.04
   ```

5. **Start every session** by printing the status summary:
   ```bash
   scripts/session-start.sh
   ```

---

## Workflow

1. Fork the repo and create a feature branch from `main`.
2. Make your changes (test-driven; write the spec first when possible).
3. Update `CHANGELOG.md` under `[Unreleased]` as you go.
4. Run `scripts/session-end.sh` — this is the canonical pre-PR gate (smoke
   + full suite + changelog hygiene + summary).
5. Run `:checkhealth headlights` in Neovim and confirm no errors.
6. Open a pull request against `main`.

---

## Coding standards

- **Pure Lua** — no external runtime dependencies.
- **`bundler.lua` must stay pure** — no `vim.api` calls; pass all data as
  arguments so it can be unit-tested without a running Neovim.
- **Logging** — use `require("headlights.log")` rather than `print` or
  `vim.notify` directly.
- **No default keymaps** — let users bind their own keys.
- **Tests** — every new public function needs at least one test; new
  integration behaviour needs a test in `tests/test_integration.lua`.
- **Cleanup** — test `post_case` hooks must undo any commands, mappings,
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
- Output of `bin/headlights --format=json` (if relevant)
- Steps to reproduce
- Expected vs. actual behaviour

---

## License

By contributing you agree that your work will be licensed under the
[MIT License](LICENSE) that covers this project.
