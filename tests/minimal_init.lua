-- Minimal init for running headlights tests via plenary.
-- Usage:
--   nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init='tests/minimal_init.lua'}"
-- or via Makefile: make test

vim.opt.runtimepath:prepend(vim.fn.getcwd())

-- Try to load plenary from common locations
local plenary_paths = {
  vim.fn.expand("~/.local/share/nvim/lazy/plenary.nvim"),
  vim.fn.expand("~/.local/share/nvim/site/pack/packer/start/plenary.nvim"),
  vim.fn.expand("~/.vim/plugged/plenary.nvim"),
  "/usr/share/nvim/runtime/pack/dist/opt/plenary.nvim",
}

for _, p in ipairs(plenary_paths) do
  if vim.fn.isdirectory(p) == 1 then
    vim.opt.runtimepath:prepend(p)
    break
  end
end
