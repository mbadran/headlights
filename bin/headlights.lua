-- bin/headlights.lua — headless entry point invoked by `bin/headlights`.
--
-- Runs the full collector → bundler → renderer pipeline without opening a
-- TUI buffer or popup, then writes the result to stdout.
--
-- Inputs (env vars set by bin/headlights):
--   HEADLIGHTS_FMT        text|markdown|json   (default: text)
--   HEADLIGHTS_FILTER     comma-separated plugin name substrings (case-insensitive)
--   HEADLIGHTS_EXTRA_RTP  comma-separated extra runtimepath entries
--   HEADLIGHTS_REPO       path to this repo (the plugin under test)
--   HEADLIGHTS_DEBUG      "1" to enable debug logging on stderr

local repo = os.getenv("HEADLIGHTS_REPO") or vim.fn.getcwd()
local fmt  = os.getenv("HEADLIGHTS_FMT")  or "text"
local raw_filter   = os.getenv("HEADLIGHTS_FILTER")    or ""
local raw_extra    = os.getenv("HEADLIGHTS_EXTRA_RTP") or ""
local debug_on     = os.getenv("HEADLIGHTS_DEBUG") == "1"

local function dlog(msg)
  if debug_on then io.stderr:write("[headlights-cli] " .. msg .. "\n") end
end

-- Make the plugin under test available on the runtimepath.
vim.opt.runtimepath:prepend(repo)

-- Add any extra rtp entries the caller asked for (typically other plugins
-- whose contributions should appear in the snapshot).
for entry in raw_extra:gmatch("[^,]+") do
  local trimmed = vim.trim(entry)
  if trimmed ~= "" then
    vim.opt.runtimepath:prepend(trimmed)
    dlog("rtp += " .. trimmed)
    -- Source the plugin's plugin/*.{vim,lua} so its commands/mappings register.
    pcall(vim.cmd, ("runtime! %s/plugin/*.vim"):format(trimmed))
    pcall(vim.cmd, ("runtime! %s/plugin/*.lua"):format(trimmed))
  end
end

-- Source our own plugin entry point, since `nvim --clean` skips it.
pcall(vim.cmd, ("runtime! %s/plugin/headlights.lua"):format(repo))

local headlights = require("headlights")
local config     = require("headlights.config")
local collector  = require("headlights.collector")
local bundler    = require("headlights.bundler")
local buffer_ui  = require("headlights.ui.buffer")

headlights.setup({
  log_level = debug_on and vim.log.levels.DEBUG or vim.log.levels.WARN,
})

-- Parse filter list.
local filter = {}
for entry in raw_filter:gmatch("[^,%s]+") do
  table.insert(filter, entry)
end

-- Build the snapshot exactly as the interactive command does.
local snap    = collector.snapshot()
local bundles = bundler.build_bundles(snap.scripts, snap.commands, snap.mappings)

if #filter > 0 then
  bundles = vim.tbl_filter(function(b)
    for _, f in ipairs(filter) do
      if b.name:lower():find(f:lower(), 1, true) then return true end
    end
    return false
  end, bundles)
end

local opts = vim.tbl_extend("force", config.options, { format = fmt })
local lines

if fmt == "json" then
  lines = buffer_ui.render_json(bundles, opts)
elseif fmt == "markdown" then
  lines = buffer_ui.render_markdown(bundles, opts)
else
  lines = buffer_ui.render_lines(bundles, opts)
end

for _, line in ipairs(lines) do
  io.stdout:write(line)
  io.stdout:write("\n")
end

vim.cmd("qa!")
