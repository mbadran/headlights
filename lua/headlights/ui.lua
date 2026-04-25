-- UI orchestrator: picks popup or buffer mode based on the running frontend.

local M = {}

--- Return true when Neovim is running inside a known graphical frontend.
--- In GUI mode we prefer the floating popup; in terminal we use a buffer.
function M.is_gui()
  -- Vim's own gui_running flag (set by GVim / some frontends)
  if vim.fn.has("gui_running") == 1 then return true end
  -- Known Neovim GUI frontends
  if vim.g.neovide      then return true end
  if vim.g.nvui         then return true end
  if vim.g.gonvim_running then return true end
  if vim.g.neoray       then return true end
  if vim.g.GuiLoaded    then return true end  -- nvim-qt sets this
  return false
end

--- Open the appropriate UI for the current environment.
--- @param bundles  table  list from bundler.build_bundles()
--- @param opts     table  config options
--- @param force    string|nil  "popup" | "buffer" to override auto-detection
function M.open(bundles, opts, force)
  if force == "popup" or (force == nil and M.is_gui()) then
    return require("headlights.ui.popup").open(bundles, opts)
  else
    return require("headlights.ui.buffer").open(bundles, opts)
  end
end

return M
