-- Public API for headlights.nvim
--
--   require("headlights").setup({ ... })
--   require("headlights").open()                  -- auto UI, all plugins
--   require("headlights").open("popup")           -- force popup
--   require("headlights").open("buffer")          -- force buffer (text)
--   require("headlights").open("buffer", {}, "json")     -- JSON output
--   require("headlights").open("buffer", {"fug"}, "md")  -- filter + format

local M = {}

local config    = require("headlights.config")
local collector = require("headlights.collector")
local bundler   = require("headlights.bundler")
local ui        = require("headlights.ui")
local log       = require("headlights.log")

--- Configure the plugin.
--- @param opts table  see lua/headlights/config.lua
function M.setup(opts)
  config.setup(opts)
  log.configure(config.options)
  log.info("setup() complete")
end

--- Collect live data and open the appropriate UI.
---
--- @param force   string|nil  "popup" | "buffer"
--- @param filter  table|nil   list of plugin name substrings (case-insensitive)
--- @param fmt     string|nil  "text" | "markdown" | "json"  (buffer only)
function M.open(force, filter, fmt)
  log.clear_perf()
  log.info(string.format("open() force=%s filter=%s fmt=%s",
    tostring(force), vim.inspect(filter or {}), tostring(fmt)))

  local ok, err = pcall(function()
    local snap = log.time("snapshot", collector.snapshot)

    local bundles = log.time("build_bundles", function()
      return bundler.build_bundles(snap.scripts, snap.commands, snap.mappings)
    end)

    -- Buffer-local items → synthetic "·buffer (local)" plugin
    local has_buf   = false
    local buf_bundle = {
      name = "·buffer (local)", root = "", scripts = {},
      commands = {}, mappings = {}, abbreviations = {}, functions = {}, highlights = {},
    }
    for name, cmd in pairs(snap.buf_commands) do
      has_buf = true
      table.insert(buf_bundle.commands, { name = name, definition = cmd.definition or "", nargs = cmd.nargs or "0" })
    end
    for mode, maps in pairs(snap.buf_mappings) do
      for _, map in ipairs(maps) do
        has_buf = true
        table.insert(buf_bundle.mappings, { mode = mode, lhs = map.lhs, rhs = map.rhs or "", desc = map.desc or "", sid = map.sid })
      end
    end
    if has_buf then
      table.sort(buf_bundle.commands, function(a, b) return a.name < b.name end)
      table.insert(bundles, buf_bundle)
    end

    -- Apply plugin name filter
    if filter and #filter > 0 then
      local matched = vim.tbl_filter(function(b)
        for _, f in ipairs(filter) do
          if b.name:lower():find(f:lower(), 1, true) then return true end
        end
        return false
      end, bundles)

      if #matched == 0 then
        local names = table.concat(filter, ", ")
        log.warn("No plugins matched: " .. names)
        vim.notify("[headlights] No plugins matched: " .. names, vim.log.levels.WARN)
        return
      end

      bundles = matched
      -- Filtered output is always in buffer mode
      if not force or force == "popup" then force = "buffer" end
    end

    log.info(string.format("displaying %d plugin(s)", #bundles))

    -- Build final opts for UI (merge format into config options)
    local ui_opts = vim.tbl_extend("force", config.options, { format = fmt or "text" })
    log.time("ui.open", ui.open, bundles, ui_opts, force)
  end)

  if not ok then
    log.error("open() failed: " .. tostring(err))
    vim.notify("[headlights] error: " .. tostring(err), vim.log.levels.ERROR)
  end
end

return M
