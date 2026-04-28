-- tests/minimal_init.lua
--
-- Bootstrap a Neovim session for headlights.nvim's tests using mini.test
-- (https://github.com/nvim-mini/mini.test).
--
-- Resolution order for mini.test:
--   1. tests/.deps/mini.test           (auto-installed by the Makefile)
--   2. $MINI_TEST                      (user override, e.g. local checkout)
--   3. ~/.local/share/nvim/site/pack/headlights-tests/start/mini.test
--   4. ~/.local/share/nvim/lazy/mini.test
--   5. ~/.local/share/nvim/lazy/mini.nvim                (mini.test ships inside)
--   6. ~/.local/share/nvim/site/pack/*/start/mini.nvim
--
-- We deliberately avoid installing mini.test on the global runtimepath at
-- import time; the Makefile clones it under tests/.deps so test runs are
-- hermetic and reproducible.

local function add(path)
  if path and path ~= "" and vim.fn.isdirectory(path) == 1 then
    vim.opt.runtimepath:prepend(path)
    return true
  end
  return false
end

-- Plugin under test
vim.opt.runtimepath:prepend(vim.fn.getcwd())

local candidates = {
  vim.fn.getcwd() .. "/tests/.deps/mini.test",
  os.getenv("MINI_TEST") or "",
  vim.fn.expand("~/.local/share/nvim/site/pack/headlights-tests/start/mini.test"),
  vim.fn.expand("~/.local/share/nvim/lazy/mini.test"),
  vim.fn.expand("~/.local/share/nvim/lazy/mini.nvim"),
}

local found
for _, c in ipairs(candidates) do
  if add(c) then found = c; break end
end

-- pack/*/start/mini.nvim is a glob — handle separately
if not found then
  local pack_glob = vim.fn.glob(vim.fn.expand("~/.local/share/nvim/site/pack/*/start/mini.nvim"), false, true)
  for _, p in ipairs(pack_glob) do
    if add(p) then found = p; break end
  end
end

if not found then
  io.stderr:write([[
[headlights tests] could not locate mini.test on disk.

Install it with:
  make test-deps          # clones nvim-mini/mini.test into tests/.deps
or set MINI_TEST=/path/to/mini.test if you have a local checkout.

]])
  os.exit(2)
end

-- Quiet defaults so test output is readable.
vim.opt.swapfile  = false
vim.opt.shortmess:append("I")

require("mini.test").setup()
