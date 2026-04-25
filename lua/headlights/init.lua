-- Public API for headlights.nvim
--
--   require("headlights").setup({ ... })   -- configure
--   require("headlights").open()           -- open the browser (auto-detect UI)
--   require("headlights").open("popup")    -- force floating popup
--   require("headlights").open("buffer")   -- force buffer mode

local M = {}

local config    = require("headlights.config")
local collector = require("headlights.collector")
local bundler   = require("headlights.bundler")
local ui        = require("headlights.ui")
local log       = require("headlights.log")

--- Configure the plugin.  Call once from your init.lua / vimrc.
--- @param opts table  see lua/headlights/config.lua for all available keys
function M.setup(opts)
  config.setup(opts)
  log.configure(config.options)
  log.info("setup() complete")
end

--- Collect live data and open the appropriate UI.
--- @param force string|nil  "popup" | "buffer" to override auto-detection
function M.open(force)
  log.clear_perf()
  log.info("open() called, force=" .. tostring(force))

  local ok, err = pcall(function()
    local snap = log.time("snapshot", collector.snapshot)

    local bundles = log.time("build_bundles", function()
      return bundler.build_bundles(snap.scripts, snap.commands, snap.mappings)
    end)

    -- Buffer-local commands / mappings → synthetic "·buffer" bundle
    local has_buf   = false
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

    log.info(string.format("found %d bundle(s)", #bundles))
    log.time("ui.open", ui.open, bundles, config.options, force)
  end)

  if not ok then
    log.error("open() failed: " .. tostring(err))
    vim.notify("[headlights] error: " .. tostring(err), vim.log.levels.ERROR)
  end
end

return M
