# Testing headlights.nvim

This document covers every way you can test the plugin: locally inside an
existing Neovim, headlessly via the CLI driver, end-to-end inside a Docker
container, and inside the automated mini.test suite.

If you just want to know "did I break anything?", run:

```bash
make smoke   # single end-to-end check (~1s)
make test    # full mini.test suite
```

---

## 1. Quality gates at a glance

| Gate                | Command                       | What it covers |
|---------------------|-------------------------------|----------------|
| **Smoke** (fast)    | `make smoke`                  | One end-to-end command via `bin/headlights` — proves the plugin loads, snapshots, and emits valid JSON. |
| **Full suite**      | `make test`                   | Every unit + integration spec under `tests/test_*.lua`. |
| **Single spec**     | `make test-file F=tests/test_bundler.lua` | One mini.test file. |
| **Lint**            | `make lint`                   | luacheck (skipped silently if not installed). |
| **CLI demo**        | `make cli`                    | Prints the live snapshot via `bin/headlights`. |
| **Docker smoke**    | `make docker-test`            | All of the above inside a fresh Ubuntu 24.04 + Neovim container. |
| **Session-end gate**| `scripts/session-end.sh`      | Runs smoke + full suite + changelog hygiene + summary. |

CI runs `smoke` then `test` on Neovim **stable** and **nightly** for every push
and pull request — see `.github/workflows/ci.yml`.

---

## 2. Local manual testing inside your own Neovim

This is the path you'll use day to day while developing.

```bash
git clone https://github.com/mbadran/headlights ~/code/headlights
```

In your `init.lua`:

```lua
vim.opt.runtimepath:prepend(vim.fn.expand("~/code/headlights"))
require("headlights").setup({
  log_level   = vim.log.levels.DEBUG,
  log_to_file = true,
})
```

Open Neovim and exercise:

```vim
:Headlights                   " auto UI
:Headlights popup             " force popup
:Headlights buffer json       " machine-readable
:Headlights fugitive          " filter by name (substring)
:checkhealth headlights       " diagnostic + perf timings
```

---

## 3. The CLI driver — `bin/headlights`

`bin/headlights` is a thin shell wrapper around `nvim -l bin/headlights.lua`.
It runs the **exact same** collector → bundler → renderer pipeline used by
`:Headlights`, but writes the result to stdout and exits — no TUI.

```bash
bin/headlights                                         # plain text
bin/headlights --format=markdown
bin/headlights --format=json   | jq '.plugins[].name'
bin/headlights fugitive,telescope --format=json        # filter + JSON
bin/headlights --rtp=/path/to/another-plugin           # snapshot extra plugins
HEADLIGHTS_DEBUG=1 bin/headlights                      # verbose stderr
```

This is what `make smoke`, `make docker-test`, and CI use under the hood.

---

## 4. Docker-based end-to-end testing on a remote Linux host

Everything below runs against a clean Ubuntu 24.04 image with Neovim installed
from the official tarball — no plugin manager, no surprises.

### 4.1 Build the image

```bash
# Local machine
make docker-build
# or, equivalently
docker build -t headlights-test -f docker/Dockerfile .
```

To use a different Neovim version, override `NVIM_VERSION`:

```bash
docker build --build-arg NVIM_VERSION=v0.11.0 \
  -t headlights-test:v0.11.0 -f docker/Dockerfile .
```

### 4.2 Run the smoke test

```bash
make docker-test                 # builds (if needed) + runs smoke
# or
docker run --rm -t headlights-test
# or
scripts/docker-test.sh
```

Expected output ends with:

```
smoke: ok (N plugin(s) reported)
```

### 4.3 Run the full mini.test suite in Docker

```bash
scripts/docker-test.sh make test
```

### 4.4 Drop into an interactive shell

```bash
scripts/docker-test.sh bash
# inside the container:
make smoke
make test
bin/headlights --format=json | head
nvim --cmd 'set rtp+=/repo' -c 'Headlights buffer'
```

### 4.5 Run on a remote Linux host

The image is self-contained, so the simplest path is "build there, run there":

```bash
# On the remote host (via ssh)
git clone https://github.com/mbadran/headlights
cd headlights
git checkout claude/review-lua-migration-0eoF6
make docker-test
```

If you'd rather build locally and ship the image:

```bash
# Local
docker build -t headlights-test -f docker/Dockerfile .
docker save headlights-test | ssh remote 'docker load'
ssh remote docker run --rm -t headlights-test
```

For an interactive Neovim TUI session over SSH:

```bash
ssh -t remote
docker run --rm -it -v $(pwd):/repo headlights-test \
  nvim --cmd 'set rtp+=/repo' -c 'Headlights buffer'
```

---

## 5. Headless / automated UI validation

You can validate the *output* of every UI mode without launching a TUI by
running the headless script directly:

```bash
# Plain text
nvim --headless --clean -l bin/headlights.lua

# JSON, then assert on shape
nvim --headless --clean -l bin/headlights.lua \
  | jq -e '.plugins | type == "array"'

# With a fixture plugin pre-loaded
HEADLIGHTS_EXTRA_RTP=$(pwd)/tests/fixtures \
  nvim --headless --clean -l bin/headlights.lua --format=json
```

For real popup/buffer rendering tests (which require a running Neovim),
mini.test uses **child Neovim processes** — see `tests/test_ui_buffer.lua`
and `tests/test_ui_popup.lua`. That's the closest you can get to "GUI
testing" without a screen.

---

## 6. Why mini.test (and not plenary)?

We migrated off `plenary.nvim`'s busted runner during this release. Trade-offs:

| Concern              | mini.test (chosen)                                  | plenary.busted (previous)                |
|----------------------|------------------------------------------------------|------------------------------------------|
| Maintenance          | Active, lives at `nvim-mini/mini.test`              | The original `nvim-lua/plenary.nvim` is in maintenance mode; a fork is still alive but uncertain. |
| Scope                | Single-purpose test framework                       | Test runner is one of many plenary modules — bigger surface area. |
| Child Neovim helper  | Built-in (`MiniTest.new_child_neovim()`)            | Hand-rolled; less ergonomic.             |
| Screen tests         | First-class screen capture                          | Not provided.                            |
| Hooks API            | `pre_case` / `post_case` (and group-level)          | busted-style `before_each` / `after_each`. |
| Install footprint    | One repo, ~1 MB                                     | plenary is several MB and pulls in extra runtime modules. |
| Tradeoff             | Idiom shift from busted (`describe`/`it` → `MiniTest.new_set` + table assignment). | Familiarity / ecosystem inertia.         |

Practical impact on this codebase:
- `tests/*_spec.lua`  →  `tests/test_*.lua`
- `describe("…", function() it("…", …) end)`
  → `T = MiniTest.new_set()` + `T["…"] = function() … end`
- `assert.are.equal(a, b)` → `MiniTest.expect.equality(a, b)`

A future minor release can swap to `mini.test`'s child-process screen tests
for the popup UI — that's the upside we're buying with this move.

---

## 7. Adding a new test

1. Create `tests/test_<area>.lua`. It must `return` a `MiniTest.new_set()`.
2. Use `MiniTest.expect.equality(actual, expected)` — that's the canonical
   assertion. Other helpers: `no_equality`, `error`, `no_error`, `match`.
3. Group hooks with `MiniTest.new_set({ hooks = { pre_case = …, post_case = … } })`.
4. Run `make test-file F=tests/test_<area>.lua` while iterating.
5. Update `CHANGELOG.md` under `[Unreleased]` if your test reflects a
   user-visible behaviour change.

---

## 8. Troubleshooting

**`mini.test not found`** — run `make test-deps` to clone it into
`tests/.deps/mini.test`, or set `MINI_TEST=/path/to/local/checkout`.

**`nvim --clean` doesn't load my plugin manager** — that's intentional.
Tests run in a deliberately minimal environment so they don't depend on
your personal config. Use `bin/headlights --rtp=/path/to/plugin` to add
extras.

**Smoke test fails with "output is not valid JSON"** — set
`HEADLIGHTS_DEBUG=1 bin/headlights --format=json` and inspect stderr.
The most common cause is a stray `print()` or `vim.notify` call leaking
into the JSON stream.

**Docker build is slow on first run** — the `make test-deps` step inside the
container clones mini.test. Subsequent layer cache hits make it near-instant.
