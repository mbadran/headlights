-- Neovim plugin entry point for headlights.nvim
-- This file is sourced automatically when the plugin is on the runtimepath.

if vim.g.loaded_headlights_lua then return end
vim.g.loaded_headlights_lua = true

-- Require Neovim 0.9+ (getscriptinfo, nvim_open_win title support)
if vim.fn.has("nvim-0.9") == 0 then
  vim.notify("headlights.nvim requires Neovim >= 0.9", vim.log.levels.WARN)
  return
end

local headlights = require("headlights")

-- :Headlights            – auto-detect UI
-- :Headlights popup      – force floating popup
-- :Headlights buffer     – force buffer mode
vim.api.nvim_create_user_command("Headlights", function(info)
  local arg = vim.trim(info.args)
  local force = (arg == "popup" or arg == "buffer") and arg or nil
  headlights.open(force)
end, {
  nargs = "?",
  complete = function() return { "popup", "buffer" } end,
  desc = "Open the Headlights plugin browser",
})

-- Convenience aliases
vim.api.nvim_create_user_command("HeadlightsPopup", function()
  headlights.open("popup")
end, { desc = "Open Headlights as a floating popup" })

vim.api.nvim_create_user_command("HeadlightsBuffer", function()
  headlights.open("buffer")
end, { desc = "Open Headlights in a buffer" })
