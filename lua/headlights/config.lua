local M = {}

M.defaults = {
  -- Display toggles
  show_commands      = true,
  show_mappings      = true,
  show_abbreviations = false,
  show_functions     = false,
  show_highlights    = false,
  show_files         = false,
  show_autocmds      = false,
  show_signs         = false,
  smart_menus        = true,
  show_load_order    = false,

  -- UI geometry
  menu_width         = 60,
  menu_max_height    = 25,

  -- Plugin discovery (#29) — extra Lua patterns for non-standard plugin
  -- directories. Each pattern is matched with `path:match(pattern)` and
  -- must capture the bundle root path AND the bundle folder name.
  -- Examples:
  --   { "^(/nix/store/[^/]+%-([^/]+))/" }              -- Nix store
  --   { "^(.*/myplugins/([^/]+))/" }                   -- custom rtp dir
  extra_plugin_dirs  = {},

  -- Logging & diagnostics (see lua/headlights/log.lua)
  -- log_level: vim.log.levels.DEBUG|INFO|WARN|ERROR  (default WARN)
  log_level          = vim.log.levels.WARN,
  -- log_to_file: write log lines to disk in addition to vim.notify
  log_to_file        = false,
  -- log_file: absolute path; nil → stdpath("log")/headlights.log
  log_file           = nil,
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

-- Initialise with defaults so the module is usable before setup() is called.
M.setup({})

return M
