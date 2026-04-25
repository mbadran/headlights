-- Public API for headlights.nvim
--
--   require("headlights").setup({ ... })   -- configure
--   require("headlights").open()           -- open the browser
--   require("headlights").open("popup")    -- force popup mode
--   require("headlights").open("buffer")   -- force buffer mode

local M = {}

local config    = require("headlights.config")
local collector = require("headlights.collector")
local bundler   = require("headlights.bundler")
local ui        = require("headlights.ui")

--- Configure the plugin.
--- @param opts table  see lua/headlights/config.lua for available keys
function M.setup(opts)
  config.setup(opts)
end

--- Collect live data and open the appropriate UI.
--- @param force string|nil  "popup" | "buffer" to override auto-detection
function M.open(force)
  local snap = collector.snapshot()

  local bundles = bundler.build_bundles(
    snap.scripts,
    snap.commands,
    snap.mappings
  )

  -- Attach abbreviations / functions / highlights to bundles.
  -- These don't carry a script_id so we can only attach them globally;
  -- show them on the bundle whose scripts list contains the longest
  -- common prefix with the current runtimepath.  As a pragmatic fallback
  -- we attach them to the last bundle that owns scripts (good enough for
  -- most single-plugin sessions).
  -- Detailed attribution is left as a future enhancement.
  -- (buf-local items are not currently attached to bundles)

  -- Buffer-local commands / mappings → separate synthetic bundle
  local has_buf = false
  local buf_bundle = {
    name          = "·buffer",
    root          = "",
    scripts       = {},
    commands      = {},
    mappings      = {},
    abbreviations = {},
    functions     = {},
    highlights    = {},
  }
  for name, cmd in pairs(snap.buf_commands) do
    has_buf = true
    table.insert(buf_bundle.commands, {
      name       = name,
      definition = cmd.definition or "",
      nargs      = cmd.nargs or "0",
    })
  end
  for mode, maps in pairs(snap.buf_mappings) do
    for _, map in ipairs(maps) do
      has_buf = true
      table.insert(buf_bundle.mappings, {
        mode = mode,
        lhs  = map.lhs,
        rhs  = map.rhs or "",
        desc = map.desc or "",
        sid  = map.sid,
      })
    end
  end
  if has_buf then
    table.sort(buf_bundle.commands, function(a, b) return a.name < b.name end)
    table.insert(bundles, buf_bundle)
  end

  ui.open(bundles, config.options, force)
end

return M
