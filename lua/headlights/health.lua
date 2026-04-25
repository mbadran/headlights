-- :checkhealth headlights
--
-- Sourced automatically when the user runs `:checkhealth headlights`.
-- Reports version compatibility, configuration, last-run timings, and
-- the number of scripts / bundles currently visible to the plugin.

local M = {}

-- Neovim 0.10 renamed the health module's top-level functions.
-- Wrap them to support both APIs.
local function h()
  local ok_fn, new_api = pcall(require, "vim.health")
  if ok_fn and new_api.start then
    return new_api
  end
  -- Neovim < 0.10 shim
  return {
    start  = vim.health.report_start,
    ok     = vim.health.report_ok,
    warn   = vim.health.report_warn,
    error  = vim.health.report_error,
    info   = vim.health.report_info,
  }
end

function M.check()
  local H = h()

  -- -----------------------------------------------------------------------
  H.start("headlights.nvim — requirements")
  -- -----------------------------------------------------------------------

  if vim.fn.has("nvim-0.9") == 1 then
    H.ok("Neovim >= 0.9")
  else
    H.error(
      "Neovim >= 0.9 is required (found " .. tostring(vim.version()) .. ")",
      { "Upgrade Neovim to 0.9 or later" }
    )
  end

  if vim.fn.exists("*getscriptinfo") == 1 then
    H.ok("getscriptinfo() available")
  else
    H.error("getscriptinfo() not available — bundle attribution will be empty")
  end

  -- -----------------------------------------------------------------------
  H.start("headlights.nvim — configuration")
  -- -----------------------------------------------------------------------

  local ok_cfg, config = pcall(require, "headlights.config")
  if not ok_cfg then
    H.error("Could not load headlights.config: " .. tostring(config))
  else
    local level_name = ({ [0] = "DEBUG", [1] = "INFO",
                          [2] = "WARN",  [3] = "ERROR" })[config.options.log_level]
                       or tostring(config.options.log_level)
    H.info("log_level:         " .. level_name)
    H.info("log_to_file:       " .. tostring(config.options.log_to_file))
    H.info("show_commands:     " .. tostring(config.options.show_commands))
    H.info("show_mappings:     " .. tostring(config.options.show_mappings))
    H.info("show_abbreviations:" .. tostring(config.options.show_abbreviations))
    H.info("show_functions:    " .. tostring(config.options.show_functions))
    H.info("show_highlights:   " .. tostring(config.options.show_highlights))
    H.info("show_files:        " .. tostring(config.options.show_files))
    H.info("smart_menus:       " .. tostring(config.options.smart_menus))
    H.ok("Configuration loaded")
  end

  -- -----------------------------------------------------------------------
  H.start("headlights.nvim — UI")
  -- -----------------------------------------------------------------------

  local ok_ui, ui = pcall(require, "headlights.ui")
  if not ok_ui then
    H.error("Could not load headlights.ui: " .. tostring(ui))
  else
    local mode = ui.is_gui()
        and "popup (GUI frontend detected)"
        or  "buffer (terminal — use :Headlights popup to force float)"
    H.info("Default UI mode: " .. mode)
    H.ok("UI module loaded")
  end

  -- -----------------------------------------------------------------------
  H.start("headlights.nvim — diagnostics")
  -- -----------------------------------------------------------------------

  local ok_log, log = pcall(require, "headlights.log")
  if ok_log then
    local perf = log.get_perf_data()
    local any  = false
    for label, ms in pairs(perf) do
      H.info(string.format("Last run — %-22s %.1f ms", label .. ":", ms))
      any = true
    end
    if not any then
      H.info("No profiling data yet (open Headlights first with :Headlights)")
    end
    if (ok_cfg and config.options.log_to_file) then
      H.info("Log file: " .. log.log_file_path())
    end
  end

  local ok_col, collector = pcall(require, "headlights.collector")
  if ok_col then
    local scripts = collector.get_scripts()
    H.info(string.format("Loaded scripts visible to headlights: %d", #scripts))

    local cmds = collector.get_commands()
    local n_cmds = 0
    for _ in pairs(cmds) do n_cmds = n_cmds + 1 end
    H.info(string.format("Global user commands visible:         %d", n_cmds))
  else
    H.warn("Could not load headlights.collector: " .. tostring(collector))
  end
end

return M
