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

function M.get_abbreviations()
  local ok, output = pcall(vim.fn.execute, "abbreviate")
  if not ok then return {} end
  local abbrevs = {}
  for line in output:gmatch("[^\n]+") do
    -- Output format:  <mode>  <lhs>   <rhs>
    -- mode chars: i=insert, c=cmd, !=both, s=select
    local mode, lhs, rhs = line:match("^%s*([ic!s])%s+(%S+)%s+(.*)")
    if mode and lhs then
      table.insert(abbrevs, { mode = mode, lhs = lhs, rhs = vim.trim(rhs) })
    end
  end
  return abbrevs
end

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

function M.get_highlights()
  local ok, output = pcall(vim.fn.execute, "highlight")
  if not ok then return {} end
  local highlights = {}
  -- Each highlight group appears as:  GroupName  xxx  <definition>
  for name in output:gmatch("([%w_@]+)%s+xxx") do
    table.insert(highlights, name)
  end
  return highlights
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
  }
end

return M
