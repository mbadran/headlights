local M = {}

function M.get_scripts()
  return vim.fn.getscriptinfo()
end

function M.get_commands()
  return vim.api.nvim_get_commands({})
end

function M.get_buf_commands()
  return vim.api.nvim_buf_get_commands(0, {})
end

function M.get_mappings(mode)
  return vim.api.nvim_get_keymap(mode)
end

function M.get_buf_mappings(mode)
  return vim.api.nvim_buf_get_keymap(0, mode)
end

-- ---------------------------------------------------------------------------
-- Abbreviations — parse `:verbose abbreviate` so we can capture the
-- "Last set from" line that follows each entry. We match the source path
-- against scripts.name in the bundler to attribute.
-- ---------------------------------------------------------------------------
function M.get_abbreviations()
  local ok, output = pcall(vim.fn.execute, "verbose abbreviate")
  if not ok then return {} end
  local abbrevs = {}
  local current
  for line in output:gmatch("[^\n]+") do
    local mode, lhs, rhs = line:match("^%s*([ic!s])%s+(%S+)%s+(.*)")
    if mode and lhs then
      current = { mode = mode, lhs = lhs, rhs = vim.trim(rhs), source = nil }
      table.insert(abbrevs, current)
    elseif current then
      local source = line:match("^%s*Last set from%s+(.-)%s+line%s+%d+")
                  or line:match("^%s*Last set from%s+(.+)$")
      if source then current.source = vim.trim(source) end
    end
  end
  return abbrevs
end

-- ---------------------------------------------------------------------------
-- Functions — derived per-script from getscriptinfo().functions, so the
-- collector returns a flat list for back-compat. The bundler attributes
-- functions directly via the per-script field.
-- ---------------------------------------------------------------------------
function M.get_functions()
  local ok, output = pcall(vim.fn.execute, "function")
  if not ok then return {} end
  local funcs = {}
  for name in output:gmatch("function ([%w_:%.#@]+)%(") do
    if not name:find("#") and not name:find("<SNR>") and not name:find("^<") then
      table.insert(funcs, name)
    end
  end
  return funcs
end

-- ---------------------------------------------------------------------------
-- Highlights — parse `:verbose highlight` to capture "Last set from".
-- Each highlight group occupies one or more lines; the optional source
-- line follows.
-- ---------------------------------------------------------------------------
function M.get_highlights()
  local ok, output = pcall(vim.fn.execute, "verbose highlight")
  if not ok then return {} end
  local highlights = {}
  local current
  for line in output:gmatch("[^\n]+") do
    local name = line:match("^([%w_@]+)%s+xxx")
    if name then
      current = { name = name, source = nil }
      table.insert(highlights, current)
    elseif current then
      local source = line:match("^%s*Last set from%s+(.-)%s+line%s+%d+")
                  or line:match("^%s*Last set from%s+(.+)$")
      if source then current.source = vim.trim(source) end
    end
  end
  return highlights
end

-- ---------------------------------------------------------------------------
-- Autocommands (#26) — nvim_get_autocmds returns global + buffer-local in
-- one shot. Each entry has `event`, `pattern`, `group_name`, `command`,
-- `desc`, and `buflocal`. We pass them straight through; the bundler
-- attributes by augroup name.
-- ---------------------------------------------------------------------------
function M.get_autocmds()
  local ok, list = pcall(vim.api.nvim_get_autocmds, {})
  if not ok then return {} end
  return list
end

-- ---------------------------------------------------------------------------
-- Signs — `sign_getdefined()` is a small but real surface (gitsigns,
-- diagnostics, dap, etc.). Returned as a flat list; attribution by sign
-- name prefix is left to the bundler.
-- ---------------------------------------------------------------------------
function M.get_signs()
  local ok, list = pcall(vim.fn.sign_getdefined)
  if not ok then return {} end
  return list
end

-- Collect all data at once and return a raw snapshot.
function M.snapshot()
  local modes = { "n", "i", "v", "x", "s", "o", "c", "t" }
  local mappings_by_mode = {}
  for _, mode in ipairs(modes) do
    mappings_by_mode[mode] = M.get_mappings(mode)
  end
  local buf_mappings_by_mode = {}
  for _, mode in ipairs(modes) do
    buf_mappings_by_mode[mode] = M.get_buf_mappings(mode)
  end
  return {
    scripts          = M.get_scripts(),
    commands         = M.get_commands(),
    buf_commands     = M.get_buf_commands(),
    mappings         = mappings_by_mode,
    buf_mappings     = buf_mappings_by_mode,
    abbreviations    = M.get_abbreviations(),
    functions        = M.get_functions(),
    highlights       = M.get_highlights(),
    autocmds         = M.get_autocmds(),
    signs            = M.get_signs(),
  }
end

return M
