-- Buffer-based display for terminal (non-GUI) Neovim.
--
-- Opens a scratch buffer named "headlights://bundles" in a vertical split
-- (or reuses an existing headlights buffer).  The buffer is read-only and
-- uses simple ASCII-art tree formatting with inline syntax highlights.

local M = {}

local BUF_NAME = "headlights://bundles"
local NS = vim.api.nvim_create_namespace("headlights_buf")

local MODE_LABELS = {
  n = "n", i = "i", v = "v", x = "x",
  s = "s", o = "o", c = "c", t = "t",
}

--------------------------------------------------------------------------
-- Pure rendering (testable)
--------------------------------------------------------------------------

--- Produce the full list of display lines for `bundles`.
--- @param bundles  table  bundle list from bundler.build_bundles()
--- @param opts     table  config options
--- @return table  list of strings
function M.render_lines(bundles, opts)
  opts = opts or {}
  local lines = {}

  -- Header
  local header = "Headlights – Plugin Browser"
  table.insert(lines, header)
  table.insert(lines, string.rep("─", math.max(40, #header)))
  table.insert(lines, "")
  table.insert(lines, "  q/<Esc> Close   <CR> Execute/Open   ? Help")
  table.insert(lines, "")

  if #bundles == 0 then
    table.insert(lines, "  (no plugin bundles detected)")
    return lines
  end

  for _, bundle in ipairs(bundles) do
    -- Bundle header
    local nscripts = #bundle.scripts
    local scripts_label = nscripts == 1 and "1 script" or (nscripts .. " scripts")
    table.insert(lines, string.format("── %s %s[%s]",
      bundle.name,
      string.rep("─", math.max(1, 44 - #bundle.name)),
      scripts_label))

    local has_content = false

    -- Commands
    if opts.show_commands ~= false and #bundle.commands > 0 then
      has_content = true
      table.insert(lines, string.format("  Commands (%d):", #bundle.commands))
      local cmd_names = {}
      for _, cmd in ipairs(bundle.commands) do
        table.insert(cmd_names, ":" .. cmd.name)
      end
      -- Wrap command names at ~70 chars
      local line, col = "    ", 4
      for i, cn in ipairs(cmd_names) do
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

    -- Mappings
    if opts.show_mappings ~= false and #bundle.mappings > 0 then
      has_content = true
      table.insert(lines, string.format("  Mappings (%d):", #bundle.mappings))
      for _, map in ipairs(bundle.mappings) do
        local mode  = MODE_LABELS[map.mode] or map.mode
        local desc  = (map.desc ~= nil and map.desc ~= "") and ("  # " .. map.desc) or ""
        table.insert(lines, string.format("    %s  %-20s → %s%s",
          mode, map.lhs, map.rhs, desc))
      end
    end

    -- Abbreviations
    if opts.show_abbreviations and #(bundle.abbreviations or {}) > 0 then
      has_content = true
      table.insert(lines, string.format("  Abbreviations (%d):", #bundle.abbreviations))
      for _, ab in ipairs(bundle.abbreviations) do
        table.insert(lines, string.format("    %s  %-16s → %s", ab.mode, ab.lhs, ab.rhs))
      end
    end

    -- Functions
    if opts.show_functions and #(bundle.functions or {}) > 0 then
      has_content = true
      table.insert(lines, string.format("  Functions (%d):", #bundle.functions))
      local fn_line = "    "
      for _, fn in ipairs(bundle.functions) do
        fn_line = fn_line .. fn .. "()  "
        if #fn_line > 70 then
          table.insert(lines, fn_line)
          fn_line = "    "
        end
      end
      if fn_line ~= "    " then table.insert(lines, fn_line) end
    end

    -- Highlights
    if opts.show_highlights and #(bundle.highlights or {}) > 0 then
      has_content = true
      table.insert(lines, string.format("  Highlights (%d):", #bundle.highlights))
      local hl_line = "    "
      for _, hl in ipairs(bundle.highlights) do
        hl_line = hl_line .. hl .. "  "
        if #hl_line > 70 then
          table.insert(lines, hl_line)
          hl_line = "    "
        end
      end
      if hl_line ~= "    " then table.insert(lines, hl_line) end
    end

    -- Files
    if opts.show_files and #bundle.scripts > 0 then
      has_content = true
      table.insert(lines, string.format("  Scripts (%d):", #bundle.scripts))
      for _, s in ipairs(bundle.scripts) do
        local suffix = s.autoload == 1 and " (autoload)" or ""
        table.insert(lines, "    " .. s.name .. suffix)
      end
    end

    if not has_content then
      table.insert(lines, "  (no visible items – check :Headlights options)")
    end

    table.insert(lines, "")
  end

  return lines
end

--------------------------------------------------------------------------
-- Buffer management
--------------------------------------------------------------------------

--- Build per-line highlight metadata from rendered lines.
--- Returns a list of { line_idx (0-based), col_start, col_end, hl_group }
local function build_highlights(lines)
  local hls = {}
  for i, line in ipairs(lines) do
    local l = i - 1
    -- Bundle header  ── Name ─── [...]
    if line:match("^──") then
      -- Highlight bundle name in bold
      local ns, ne = line:find("[A-Za-z][%w%.%-_]+")
      if ns then
        table.insert(hls, { l, ns - 1, ne, "Title" })
      end
      -- Highlight the [N scripts] count
      local ss, se = line:find("%[.-%]")
      if ss then
        table.insert(hls, { l, ss - 1, se, "Comment" })
      end

    -- Sub-header: "  Commands (3):"
    elseif line:match("^  %u%l") then
      table.insert(hls, { l, 0, #line, "Statement" })

    -- Command lines: "    :Foo  :Bar"
    elseif line:match("^    :") then
      for s, e in line:gmatch("():%a[%w_!]+()") do
        table.insert(hls, { l, s - 1, e - 1, "Function" })
      end

    -- Mapping lines: "    n  <leader>gs → :cmd"
    elseif line:match("^    %a  ") then
      -- Mode char
      table.insert(hls, { l, 4, 5, "Keyword" })
      -- LHS
      local ls, le = line:find("%S+", 7)
      if ls then table.insert(hls, { l, ls - 1, le, "String" }) end
      -- Arrow
      local as_, ae = line:find("→")
      if as_ then table.insert(hls, { l, as_ - 1, ae, "Operator" }) end
      -- Comment (#...)
      local cs, ce = line:find("  # .+$")
      if cs then table.insert(hls, { l, cs + 1, ce, "Comment" }) end
    end
  end
  return hls
end

--- Open (or reuse) the headlights buffer and return its buffer number.
--- @param bundles  table  list from bundler.build_bundles()
--- @param opts     table  config options
--- @return number  buffer handle
function M.open(bundles, opts)
  opts = opts or {}

  -- Reuse existing buffer if already open
  local existing_buf
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf)
      and vim.api.nvim_buf_get_name(buf) == BUF_NAME then
      existing_buf = buf
      break
    end
  end

  local buf
  if existing_buf then
    buf = existing_buf
    -- Switch to the window showing it, or open a new split
    local found_win = false
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == buf then
        vim.api.nvim_set_current_win(win)
        found_win = true
        break
      end
    end
    if not found_win then
      vim.cmd("vsplit")
      vim.api.nvim_win_set_buf(0, buf)
    end
  else
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, BUF_NAME)
    vim.cmd("vsplit")
    vim.api.nvim_win_set_buf(0, buf)
  end

  -- Render and write
  local lines = M.render_lines(bundles, opts)
  vim.api.nvim_set_option_value("modifiable",  true,  { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable",  false, { buf = buf })
  vim.api.nvim_set_option_value("buftype",     "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden",   "hide",   { buf = buf })
  vim.api.nvim_set_option_value("swapfile",    false,    { buf = buf })
  vim.api.nvim_set_option_value("filetype",    "headlights", { buf = buf })

  -- Apply highlights
  vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
  for _, h in ipairs(build_highlights(lines)) do
    vim.api.nvim_buf_add_highlight(buf, NS, h[4], h[1], h[2], h[3])
  end

  -- Keymaps
  local function km(lhs, rhs_fn)
    vim.keymap.set("n", lhs, rhs_fn, { buffer = buf, nowait = true, silent = true })
  end

  km("q",     function() vim.api.nvim_buf_delete(buf, { force = true }) end)
  km("<Esc>", function() vim.api.nvim_buf_delete(buf, { force = true }) end)
  km("?",     function()
    vim.api.nvim_echo({
      { "Headlights keymaps: ", "Title" },
      { "q/<Esc>", "Function" }, { " close  ", "Normal" },
      { "<CR>", "Function" }, { " run command / open file / help", "Normal" },
    }, true, {})
  end)

  -- <CR> on a command line → run it
  km("<CR>", function()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local line = lines[row] or ""
    -- Detect ":CommandName" items
    local cmd_name = line:match("^%s*:([A-Z][%w_!]*)")
    if cmd_name then
      vim.api.nvim_buf_delete(buf, { force = true })
      vim.api.nvim_feedkeys(":" .. cmd_name .. " ", "n", false)
      return
    end
    -- Detect file paths
    local filepath = line:match("^%s+(/[^%(]+%.[%a]+)")
    if filepath then
      vim.api.nvim_buf_delete(buf, { force = true })
      vim.cmd("edit " .. vim.fn.fnameescape(vim.trim(filepath)))
    end
  end)

  return buf
end

return M
