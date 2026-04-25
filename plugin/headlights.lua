-- Neovim plugin entry point for headlights.nvim
-- Sourced automatically when the plugin is on the runtimepath.

if vim.g.loaded_headlights_lua then return end
vim.g.loaded_headlights_lua = true

if vim.fn.has("nvim-0.9") == 0 then
  vim.notify("headlights.nvim requires Neovim >= 0.9", vim.log.levels.WARN)
  return
end

local headlights = require("headlights")

-- Command argument parser -------------------------------------------------
-- Handles any mix of:
--   :Headlights                       all plugins, auto UI
--   :Headlights popup                 force popup
--   :Headlights buffer                force buffer (text format)
--   :Headlights buffer json           force buffer, JSON format
--   :Headlights buffer markdown       force buffer, Markdown format
--   :Headlights fugitive              filter to fugitive, buffer output
--   :Headlights fugitive,telescope    filter to multiple plugins
--   :Headlights fugitive json         filter + JSON format
-- -------------------------------------------------------------------------
local FORMATS = { text = true, markdown = true, json = true }
local MODES   = { popup = true, buffer = true }

local function parse_args(raw)
  local force, fmt, filter = nil, nil, {}
  local tokens = vim.split(vim.trim(raw), "[%s,]+", { trimempty = true })
  for _, tok in ipairs(tokens) do
    if     MODES[tok]   then force = tok
    elseif FORMATS[tok] then fmt   = tok
    else                     table.insert(filter, tok)
    end
  end
  -- A format arg implies buffer mode
  if fmt and not force then force = "buffer" end
  -- A filter implies buffer mode
  if #filter > 0 and not force then force = "buffer" end
  return force, filter, fmt
end

-- Completion helper
local function complete_headlights(arglead)
  local static = { "popup", "buffer", "text", "markdown", "json" }
  local result = {}
  for _, s in ipairs(static) do
    if s:find(arglead, 1, true) == 1 then table.insert(result, s) end
  end
  return result
end

-- :Headlights [args...]
vim.api.nvim_create_user_command("Headlights", function(info)
  local force, filter, fmt = parse_args(info.args)
  headlights.open(force, filter, fmt)
end, {
  nargs    = "*",
  complete = complete_headlights,
  desc     = "Open the Headlights plugin browser",
})

-- Convenience shortcuts
vim.api.nvim_create_user_command("HeadlightsPopup", function()
  headlights.open("popup")
end, { desc = "Open Headlights as a floating popup" })

vim.api.nvim_create_user_command("HeadlightsBuffer", function(info)
  local _, _, fmt = parse_args(info.args)
  headlights.open("buffer", {}, fmt)
end, {
  nargs    = "?",
  complete = function(arglead) return complete_headlights(arglead) end,
  desc     = "Open Headlights in a buffer [text|markdown|json]",
})
