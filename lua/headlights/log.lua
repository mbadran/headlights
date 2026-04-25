-- Structured logging and performance profiling for headlights.nvim.
--
-- Usage:
--   local log = require("headlights.log")
--   log.debug("verbose detail")
--   log.info("something noteworthy")
--   log.warn("potential problem")
--   log.error("something broke")
--
--   local result = log.time("snapshot", collector.snapshot)
--
-- Configuration (set via headlights.setup):
--   log_level   – minimum level to emit (default: WARN).  Use vim.log.levels.
--   log_to_file – also append to a log file (default: false)
--   log_file    – absolute path; nil → stdpath("log")/headlights.log

local M = {}

-- -------------------------------------------------------------------------
-- State (module-private, reconfigured by M.configure)
-- -------------------------------------------------------------------------

local _opts = {
  level     = vim.log.levels.WARN,
  to_file   = false,
  file_path = nil,   -- resolved lazily below
}

-- Stores { label = elapsed_ms } for the most recent open() call.
local _perf = {}

-- -------------------------------------------------------------------------
-- Setup
-- -------------------------------------------------------------------------

function M.configure(opts)
  opts = opts or {}
  if opts.log_level   ~= nil then _opts.level     = opts.log_level   end
  if opts.log_to_file ~= nil then _opts.to_file   = opts.log_to_file end
  if opts.log_file    ~= nil then _opts.file_path = opts.log_file    end
end

-- -------------------------------------------------------------------------
-- Internal helpers
-- -------------------------------------------------------------------------

local LEVEL_NAMES = { [0] = "DEBUG", [1] = "INFO", [2] = "WARN", [3] = "ERROR" }

local function log_file_path()
  return _opts.file_path or (vim.fn.stdpath("log") .. "/headlights.log")
end

local function append_to_file(line)
  local fh = io.open(log_file_path(), "a")
  if not fh then return end
  fh:write(line .. "\n")
  fh:close()
end

local function emit(level, msg)
  if level < _opts.level then return end

  local lname = LEVEL_NAMES[level] or "LOG"
  local ts    = os.date("%H:%M:%S")
  local line  = string.format("[headlights %s %s] %s", ts, lname, msg)

  -- notify() must run on the main loop when called from async contexts
  if level >= vim.log.levels.WARN
      or (_opts.level <= vim.log.levels.INFO and level >= vim.log.levels.INFO)
  then
    vim.schedule(function()
      vim.notify(line, level, { title = "headlights" })
    end)
  end

  if _opts.to_file then
    local full_ts = os.date("%Y-%m-%dT%H:%M:%S")
    append_to_file(full_ts .. " " .. line)
  end
end

-- -------------------------------------------------------------------------
-- Public logging API
-- -------------------------------------------------------------------------

function M.debug(msg) emit(vim.log.levels.DEBUG, msg) end
function M.info(msg)  emit(vim.log.levels.INFO,  msg) end
function M.warn(msg)  emit(vim.log.levels.WARN,  msg) end
function M.error(msg) emit(vim.log.levels.ERROR, msg) end

-- -------------------------------------------------------------------------
-- Performance timing
-- -------------------------------------------------------------------------

-- High-resolution clock: prefer vim.uv (Neovim 0.10+), fall back to vim.loop.
local function hrtime()
  return (vim.uv or vim.loop).hrtime()
end

--- Time `fn(...)`, record under `label`, return fn's results.
---
--- @param label string  human-readable name logged and stored in perf table
--- @param fn    function
--- @param ...   any     forwarded to fn
--- @return any  whatever fn returned
function M.time(label, fn, ...)
  local t0     = hrtime()
  local result = { fn(...) }
  local elapsed = (hrtime() - t0) / 1e6   -- nanoseconds → milliseconds
  _perf[label]  = elapsed
  M.debug(string.format("perf: %s took %.2f ms", label, elapsed))
  return table.unpack(result)
end

--- Return a snapshot of all recorded timings (copies, not references).
--- @return table  { label = ms }
function M.get_perf_data()
  return vim.deepcopy(_perf)
end

--- Reset the timing table (called automatically at the start of each open()).
function M.clear_perf()
  _perf = {}
end

--- Return the path where log file entries are written.
function M.log_file_path()
  return log_file_path()
end

return M
