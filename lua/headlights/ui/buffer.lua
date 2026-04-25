-- Buffer-based display for terminal Neovim.
--
-- Formats: "text" (default), "markdown", "json"
-- Opens as a scratch buffer named "headlights://plugins" in a vsplit.

local M = {}

local BUF_NAME = "headlights://plugins"
local NS = vim.api.nvim_create_namespace("headlights_buf")

local LOGO = "  ◉  ◉   headlights.nvim"
local LOGO_ASCII = "  O  O   headlights.nvim"   -- for help file / plain text

local MODE_LABELS = {
  n = "n", i = "i", v = "v", x = "x",
  s = "s", o = "o", c = "c", t = "t",
}

--------------------------------------------------------------------------
-- Plain-text renderer (testable, no Vim API calls)
--------------------------------------------------------------------------

--- @param bundles table   list from bundler.build_bundles()
--- @param opts    table   config options
--- @return table          list of strings
function M.render_lines(bundles, opts)
  opts = opts or {}
  local lines = {}

  table.insert(lines, LOGO)
  table.insert(lines, string.rep("─", 50))
  table.insert(lines, "  q/<Esc> Close   <CR> Execute/Open   ? Help")
  table.insert(lines, "")

  if #bundles == 0 then
    table.insert(lines, "  (no plugins detected)")
    return lines
  end

  for _, bundle in ipairs(bundles) do
    local nscripts = #bundle.scripts
    local slabel   = nscripts == 1 and "1 script" or (nscripts .. " scripts")
    table.insert(lines, string.format("── %s %s[%s]",
      bundle.name,
      string.rep("─", math.max(1, 44 - #bundle.name)),
      slabel))

    local has_content = false

    if opts.show_commands ~= false and #bundle.commands > 0 then
      has_content = true
      table.insert(lines, string.format("  Commands (%d):", #bundle.commands))
      local line, col = "    ", 4
      for i, cmd in ipairs(bundle.commands) do
        local cn  = ":" .. cmd.name
        local sep = i > 1 and "  " or ""
        if col + #sep + #cn > 72 and col > 4 then
          table.insert(lines, line)
          line, col = "    " .. cn, 4 + #cn
        else
          line = line .. sep .. cn
          col  = col + #sep + #cn
        end
      end
      if col > 4 then table.insert(lines, line) end
    end

    if opts.show_mappings ~= false and #bundle.mappings > 0 then
      has_content = true
      table.insert(lines, string.format("  Mappings (%d):", #bundle.mappings))
      for _, map in ipairs(bundle.mappings) do
        local mode = MODE_LABELS[map.mode] or map.mode
        local desc = (map.desc and map.desc ~= "") and ("  # " .. map.desc) or ""
        table.insert(lines, string.format("    %s  %-20s → %s%s",
          mode, map.lhs, map.rhs, desc))
      end
    end

    if opts.show_abbreviations and #(bundle.abbreviations or {}) > 0 then
      has_content = true
      table.insert(lines, string.format("  Abbreviations (%d):", #bundle.abbreviations))
      for _, ab in ipairs(bundle.abbreviations) do
        table.insert(lines, string.format("    %s  %-16s → %s", ab.mode, ab.lhs, ab.rhs))
      end
    end

    if opts.show_functions and #(bundle.functions or {}) > 0 then
      has_content = true
      table.insert(lines, string.format("  Functions (%d):", #bundle.functions))
      local fl = "    "
      for _, fn in ipairs(bundle.functions) do
        fl = fl .. fn .. "()  "
        if #fl > 70 then table.insert(lines, fl); fl = "    " end
      end
      if fl ~= "    " then table.insert(lines, fl) end
    end

    if opts.show_highlights and #(bundle.highlights or {}) > 0 then
      has_content = true
      table.insert(lines, string.format("  Highlights (%d):", #bundle.highlights))
      local hl = "    "
      for _, h in ipairs(bundle.highlights) do
        hl = hl .. h .. "  "
        if #hl > 70 then table.insert(lines, hl); hl = "    " end
      end
      if hl ~= "    " then table.insert(lines, hl) end
    end

    if opts.show_files and #bundle.scripts > 0 then
      has_content = true
      table.insert(lines, string.format("  Scripts (%d):", #bundle.scripts))
      for _, s in ipairs(bundle.scripts) do
        table.insert(lines, "    " .. s.name .. (s.autoload == 1 and " (autoload)" or ""))
      end
    end

    if not has_content then
      table.insert(lines, "  (no visible items — adjust show_* options in setup())")
    end

    table.insert(lines, "")
  end

  return lines
end

--------------------------------------------------------------------------
-- Markdown renderer
--------------------------------------------------------------------------

--- @param bundles table
--- @param opts    table
--- @return table          list of strings (Markdown)
function M.render_markdown(bundles, opts)
  opts = opts or {}
  local lines = {}
  local function ln(s) table.insert(lines, s or "") end

  ln("# headlights.nvim — Plugin Browser")
  ln()
  ln(string.format("*Generated %s · Neovim %s*", os.date("%Y-%m-%d"), tostring(vim.version())))
  ln()

  if #bundles == 0 then
    ln("> No plugins detected.")
    return lines
  end

  for _, bundle in ipairs(bundles) do
    ln("## " .. bundle.name)
    ln()

    if opts.show_commands ~= false and #bundle.commands > 0 then
      ln("### Commands")
      ln()
      ln("| Command | Args | Definition |")
      ln("|---------|------|------------|")
      for _, cmd in ipairs(bundle.commands) do
        local def = (cmd.definition or ""):gsub("|", "\\|"):gsub("`", "'")
        ln(string.format("| `:%s` | `%s` | `%s` |", cmd.name, cmd.nargs or "0", def))
      end
      ln()
    end

    if opts.show_mappings ~= false and #bundle.mappings > 0 then
      ln("### Mappings")
      ln()
      ln("| Mode | LHS | RHS | Description |")
      ln("|------|-----|-----|-------------|")
      for _, map in ipairs(bundle.mappings) do
        local rhs  = (map.rhs  or ""):gsub("|", "\\|"):gsub("`", "'")
        local desc = (map.desc or ""):gsub("|", "\\|")
        ln(string.format("| `%s` | `%s` | `%s` | %s |",
          map.mode, map.lhs, rhs, desc))
      end
      ln()
    end

    if opts.show_files and #bundle.scripts > 0 then
      ln("### Scripts")
      ln()
      for _, s in ipairs(bundle.scripts) do
        ln(string.format("- `%s`%s", s.name, s.autoload == 1 and " *(autoload)*" or ""))
      end
      ln()
    end

    ln("---")
    ln()
  end

  return lines
end

--------------------------------------------------------------------------
-- JSON renderer
--------------------------------------------------------------------------

--- Produce a JSON representation.  Returns a single-element list whose
--- only entry is the encoded string (so callers can treat it like other
--- render_* functions when writing to a buffer).
--- @param bundles table
--- @param opts    table
--- @return table  { json_string }
function M.render_json(bundles, opts)
  opts = opts or {}
  local data = {
    generated      = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    neovim_version = tostring(vim.version()),
    plugins        = {},
  }

  for _, bundle in ipairs(bundles) do
    local entry = { name = bundle.name, root = bundle.root }

    if opts.show_commands ~= false then
      entry.commands = bundle.commands
    end
    if opts.show_mappings ~= false then
      entry.mappings = bundle.mappings
    end
    if opts.show_abbreviations then
      entry.abbreviations = bundle.abbreviations
    end
    if opts.show_functions then
      entry.functions = bundle.functions
    end
    if opts.show_highlights then
      entry.highlights = bundle.highlights
    end
    if opts.show_files then
      entry.scripts = vim.tbl_map(function(s)
        return { sid = s.sid, name = s.name, autoload = s.autoload == 1 }
      end, bundle.scripts)
    end

    table.insert(data.plugins, entry)
  end

  local ok, encoded = pcall(vim.json.encode, data)
  if not ok then
    return { '{"error": "JSON encoding failed: ' .. tostring(encoded) .. '"}' }
  end

  -- Pretty-print by inserting newlines after top-level keys (basic)
  return { encoded }
end

--------------------------------------------------------------------------
-- Dispatch
--------------------------------------------------------------------------

--- Route to the correct renderer based on opts.format.
--- @param bundles table
--- @param opts    table   opts.format = "text"|"markdown"|"json"
--- @return table  list of strings
function M.render(bundles, opts)
  opts = opts or {}
  local fmt = opts.format or "text"
  if fmt == "json"     then return M.render_json(bundles, opts) end
  if fmt == "markdown" then return M.render_markdown(bundles, opts) end
  return M.render_lines(bundles, opts)
end

--------------------------------------------------------------------------
-- Syntax highlights for text format
--------------------------------------------------------------------------

local function build_highlights(lines)
  local hls = {}
  for i, line in ipairs(lines) do
    local l = i - 1
    if line:match("^  ◉") or line:match("^  O") then
      table.insert(hls, { l, 0, #line, "Title" })
    elseif line:match("^──") then
      local ns, ne = line:find("[%w%-%._◉]+", 5)
      if ns then table.insert(hls, { l, ns - 1, ne, "Title" }) end
      local ss, se = line:find("%[.-%]")
      if ss then table.insert(hls, { l, ss - 1, se, "Comment" }) end
    elseif line:match("^  %u%l") then
      table.insert(hls, { l, 0, #line, "Statement" })
    elseif line:match("^    :") then
      for s, e in line:gmatch("():%a[%w_!]+()") do
        table.insert(hls, { l, s - 1, e - 1, "Function" })
      end
    elseif line:match("^    %a  ") then
      table.insert(hls, { l, 4, 5, "Keyword" })
      local ls, le = line:find("%S+", 7)
      if ls then table.insert(hls, { l, ls - 1, le, "String" }) end
      local as_, ae = line:find("→")
      if as_ then table.insert(hls, { l, as_ - 1, ae, "Operator" }) end
      local cs, ce = line:find("  # .+$")
      if cs then table.insert(hls, { l, cs + 1, ce, "Comment" }) end
    end
  end
  return hls
end

--------------------------------------------------------------------------
-- Buffer management
--------------------------------------------------------------------------

--- Open (or reuse) the headlights buffer.
--- @param bundles  table
--- @param opts     table  opts.format = "text"|"markdown"|"json"
--- @return number  buffer handle
function M.open(bundles, opts)
  opts = opts or {}
  local fmt = opts.format or "text"

  -- Unique buffer name per format so they can coexist
  local buf_name = fmt == "text" and BUF_NAME
      or ("headlights://plugins." .. fmt)

  local existing_buf
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf)
        and vim.api.nvim_buf_get_name(buf) == buf_name then
      existing_buf = buf; break
    end
  end

  local buf
  if existing_buf then
    buf = existing_buf
    local found = false
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == buf then
        vim.api.nvim_set_current_win(win); found = true; break
      end
    end
    if not found then vim.cmd("vsplit"); vim.api.nvim_win_set_buf(0, buf) end
  else
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, buf_name)
    vim.cmd("vsplit")
    vim.api.nvim_win_set_buf(0, buf)
  end

  local lines = M.render(bundles, opts)

  vim.api.nvim_set_option_value("modifiable", true,          { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false,         { buf = buf })
  vim.api.nvim_set_option_value("buftype",    "nofile",      { buf = buf })
  vim.api.nvim_set_option_value("bufhidden",  "hide",        { buf = buf })
  vim.api.nvim_set_option_value("swapfile",   false,         { buf = buf })
  vim.api.nvim_set_option_value("filetype",   "headlights",  { buf = buf })

  -- Highlights only make sense for plain-text format
  if fmt == "text" then
    vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
    for _, h in ipairs(build_highlights(lines)) do
      vim.api.nvim_buf_add_highlight(buf, NS, h[4], h[1], h[2], h[3])
    end
  end

  local function km(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true })
  end

  km("q",     function() vim.api.nvim_buf_delete(buf, { force = true }) end)
  km("<Esc>", function() vim.api.nvim_buf_delete(buf, { force = true }) end)
  km("?", function()
    vim.api.nvim_echo({
      { "q/<Esc>", "Function" }, { " close  ", "Normal" },
      { "<CR>", "Function" }, { " run command / open file", "Normal" },
    }, true, {})
  end)
  km("<CR>", function()
    local row  = vim.api.nvim_win_get_cursor(0)[1]
    local line = lines[row] or ""
    local cmd_name = line:match("^%s*:([A-Z][%w_!]*)")
    if cmd_name then
      vim.api.nvim_buf_delete(buf, { force = true })
      vim.api.nvim_feedkeys(":" .. cmd_name .. " ", "n", false)
      return
    end
    local filepath = line:match("^%s+(/[^%(]+%.[%a]+)")
    if filepath then
      vim.api.nvim_buf_delete(buf, { force = true })
      vim.cmd("edit " .. vim.fn.fnameescape(vim.trim(filepath)))
    end
  end)

  return buf
end

return M
