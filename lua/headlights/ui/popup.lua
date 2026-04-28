-- Hierarchical floating-window popup UI for graphical Neovim frontends.
--
-- Navigation model:
--   Level 1 – bundle list
--   Level 2 – category list for the selected bundle
--   Level 3 – item list for the selected category
--
-- Each level replaces the content of the same floating window and updates
-- the title so the user always knows where they are (breadcrumb).

local M = {}

local MODE_LABELS = {
  n = "Normal",  i = "Insert",  v = "Visual",  x = "Visual(x)",
  s = "Select",  o = "Op-pend", c = "Command", t = "Terminal",
}

local CATEGORIES = { "commands", "mappings", "abbreviations", "functions", "highlights", "autocmds", "signs", "files" }

local CATEGORY_LABELS = {
  commands      = "Commands",
  mappings      = "Mappings",
  abbreviations = "Abbreviations",
  functions     = "Functions",
  highlights    = "Highlights",
  autocmds      = "Autocommands",
  signs         = "Signs",
  files         = "Files",
}

-- Maps category key → option key in config
local CATEGORY_OPTION = {
  commands      = "show_commands",
  mappings      = "show_mappings",
  abbreviations = "show_abbreviations",
  functions     = "show_functions",
  highlights    = "show_highlights",
  autocmds      = "show_autocmds",
  signs         = "show_signs",
  files         = "show_files",
}

--------------------------------------------------------------------------
-- Pure helpers (testable without opening windows)
--------------------------------------------------------------------------

--- Build the lines and entry metadata for the current navigation level.
--- @param bundles      table   full bundle list
--- @param bundle       table|nil  selected bundle (nil = level 1)
--- @param category     string|nil  selected category (nil = level 1 or 2)
--- @param opts         table   config options
--- @return lines table, entries table
function M.build_menu_lines(bundles, bundle, category, opts)
  opts = opts or {}

  if not bundle then
    return M._bundle_list_lines(bundles, opts)
  elseif not category then
    return M._category_list_lines(bundle, opts)
  else
    return M._item_list_lines(bundle, category, opts)
  end
end

function M._bundle_list_lines(bundles, _opts)
  local lines, entries = {}, {}
  for _, b in ipairs(bundles) do
    local ncmds  = #b.commands
    local nmaps  = #b.mappings
    local detail = ""
    if ncmds > 0 then detail = detail .. ncmds .. " cmd" .. (ncmds ~= 1 and "s" or "") end
    if nmaps > 0 then
      if detail ~= "" then detail = detail .. "  " end
      detail = detail .. nmaps .. " map" .. (nmaps ~= 1 and "s" or "")
    end
    local suffix = detail ~= "" and ("  [" .. detail .. "]") or ""
    table.insert(lines, "  " .. b.name .. suffix)
    table.insert(entries, { type = "bundle", bundle = b })
  end
  return lines, entries
end

function M._category_list_lines(bundle, opts)
  local lines, entries = {}, {}
  -- Always offer a Help entry when there are scripts
  if #bundle.scripts > 0 then
    table.insert(lines, "  Help")
    table.insert(entries, { type = "category", category = "help" })
  end
  for _, cat in ipairs(CATEGORIES) do
    local items = bundle[cat] or {}
    local opt_key = CATEGORY_OPTION[cat]
    -- Show the category if it has items and either the option is on or unset
    if #items > 0 and (opts[opt_key] ~= false) then
      local label = CATEGORY_LABELS[cat]
      table.insert(lines, string.format("  %-16s [%d]", label, #items))
      table.insert(entries, { type = "category", category = cat })
    end
  end
  return lines, entries
end

function M._item_list_lines(bundle, category, _opts)
  local lines, entries = {}, {}
  if category == "help" then
    for _, s in ipairs(bundle.scripts) do
      local fname = s.name:match("([^/]+)$") or s.name
      table.insert(lines, "  :help " .. fname:gsub("%.[^.]+$", ""))
      table.insert(entries, { type = "help", script = s })
    end
  elseif category == "commands" then
    for _, cmd in ipairs(bundle.commands) do
      local nargs = cmd.nargs ~= "0" and (" <" .. cmd.nargs .. ">") or ""
      table.insert(lines, "  :" .. cmd.name .. nargs)
      table.insert(entries, { type = "command", command = cmd })
    end
  elseif category == "mappings" then
    for _, map in ipairs(bundle.mappings) do
      local mode_label = MODE_LABELS[map.mode] or map.mode
      local desc = map.desc ~= "" and ("  # " .. map.desc) or ""
      table.insert(lines, string.format("  %-8s  %s → %s%s",
        mode_label, map.lhs, map.rhs, desc))
      table.insert(entries, { type = "mapping", mapping = map })
    end
  elseif category == "abbreviations" then
    for _, ab in ipairs(bundle.abbreviations or {}) do
      table.insert(lines, string.format("  %s  %s → %s", ab.mode, ab.lhs, ab.rhs))
      table.insert(entries, { type = "abbreviation", abbrev = ab })
    end
  elseif category == "functions" then
    for _, fn in ipairs(bundle.functions or {}) do
      table.insert(lines, "  " .. fn .. "()")
      table.insert(entries, { type = "function", fn = fn })
    end
  elseif category == "highlights" then
    for _, hl in ipairs(bundle.highlights or {}) do
      table.insert(lines, "  " .. hl)
      table.insert(entries, { type = "highlight", hl = hl })
    end
  elseif category == "autocmds" then
    for _, ac in ipairs(bundle.autocmds or {}) do
      local pat  = ac.pattern or ""
      local grp  = ac.group_name or ac.group or ""
      local desc = ac.desc or ""
      table.insert(lines, string.format("  %-12s %-22s [%s] %s",
        ac.event or "?", pat, grp, desc))
      table.insert(entries, { type = "autocmd", autocmd = ac })
    end
  elseif category == "signs" then
    for _, sg in ipairs(bundle.signs or {}) do
      table.insert(lines, "  " .. (sg.name or "?")
        .. (sg.text and (" " .. sg.text) or ""))
      table.insert(entries, { type = "sign", sign = sg })
    end
  elseif category == "files" then
    for _, s in ipairs(bundle.scripts) do
      table.insert(lines, "  " .. s.name)
      table.insert(entries, { type = "file", script = s })
    end
  end
  return lines, entries
end

--------------------------------------------------------------------------
-- Window management
--------------------------------------------------------------------------

local BORDER = "rounded"
local NS = vim.api.nvim_create_namespace("headlights_popup")

local function popup_dimensions(opts)
  local width  = opts.menu_width or 60
  local height = opts.menu_max_height or 25
  local row    = math.floor((vim.o.lines   - height) / 2)
  local col    = math.floor((vim.o.columns - width)  / 2)
  return width, height, row, col
end

local function make_title(bundle, category)
  if not bundle then
    return " Headlights › Plugins "
  elseif not category then
    return " Headlights › Plugins › " .. bundle.name .. " "
  else
    return " Headlights › Plugins › " .. bundle.name .. " › "
        .. (CATEGORY_LABELS[category] or category) .. " "
  end
end

--- (Re)populate `buf` with `lines` and apply highlights.
local function fill_buffer(buf, lines)
  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  -- Dim the detail annotations ([N cmds]) on bundle-list lines
  vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
  for i, line in ipairs(lines) do
    local s, e = line:find("%[.-%]")
    if s then
      vim.api.nvim_buf_add_highlight(buf, NS, "Comment", i - 1, s - 1, e)
    end
  end
end

--- Update window title (border title) to reflect current breadcrumb.
local function set_title(win, bundle, category)
  vim.api.nvim_win_set_config(win, {
    title     = make_title(bundle, category),
    title_pos = "center",
  })
end

--- Bind navigation keys for the current level.
local function bind_keys(buf, win, bundles, bundle, category, opts)
  local function remap(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true })
  end

  -- Close
  remap("q",     function() vim.api.nvim_win_close(win, true) end)
  remap("<Esc>", function() vim.api.nvim_win_close(win, true) end)

  -- Go back one level
  if bundle then
    local function go_back()
      local new_bundle   = category and bundle or nil
      local new_category = nil
      local lines, _     = M.build_menu_lines(bundles, new_bundle, new_category, opts)
      fill_buffer(buf, lines)
      set_title(win, new_bundle, new_category)
      bind_keys(buf, win, bundles, new_bundle, new_category, opts)
      vim.api.nvim_win_set_cursor(win, { 1, 0 })
    end
    remap("<BS>",    go_back)
    remap("<Left>",  go_back)
    remap("h",       go_back)
  end

  -- Select / drill down
  remap("<CR>", function()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    local _, entries = M.build_menu_lines(bundles, bundle, category, opts)
    local entry = entries[row]
    if not entry then return end

    if entry.type == "bundle" then
      local lines, _ = M.build_menu_lines(bundles, entry.bundle, nil, opts)
      fill_buffer(buf, lines)
      set_title(win, entry.bundle, nil)
      bind_keys(buf, win, bundles, entry.bundle, nil, opts)
      vim.api.nvim_win_set_cursor(win, { 1, 0 })

    elseif entry.type == "category" then
      local lines, _ = M.build_menu_lines(bundles, bundle, entry.category, opts)
      fill_buffer(buf, lines)
      set_title(win, bundle, entry.category)
      bind_keys(buf, win, bundles, bundle, entry.category, opts)
      vim.api.nvim_win_set_cursor(win, { 1, 0 })

    elseif entry.type == "command" then
      vim.api.nvim_win_close(win, true)
      vim.api.nvim_feedkeys(":" .. entry.command.name .. " ", "n", false)

    elseif entry.type == "help" then
      local name = (entry.script.name:match("([^/]+)$") or ""):gsub("%.[^.]+$", "")
      vim.api.nvim_win_close(win, true)
      pcall(vim.cmd, "help " .. name)

    elseif entry.type == "mapping" then
      vim.api.nvim_win_close(win, true)
      -- Echo the mapping info; user can act on it
      vim.api.nvim_echo({{ entry.mapping.lhs .. " → " .. entry.mapping.rhs, "Normal" }}, true, {})

    elseif entry.type == "file" then
      vim.api.nvim_win_close(win, true)
      vim.cmd("edit " .. vim.fn.fnameescape(entry.script.name))
    end
  end)
end

--- Open the hierarchical popup. Returns the window handle.
--- @param bundles table   list from bundler.build_bundles()
--- @param opts    table   config options
--- @return number  window handle
function M.open(bundles, opts)
  opts = opts or {}
  local width, height, row, col = popup_dimensions(opts)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("bufhidden", "wipe",  { buf = buf })
  vim.api.nvim_set_option_value("filetype",  "headlights", { buf = buf })

  local lines, _ = M.build_menu_lines(bundles, nil, nil, opts)
  fill_buffer(buf, lines)

  local win = vim.api.nvim_open_win(buf, true, {
    relative   = "editor",
    row        = row,
    col        = col,
    width      = width,
    height     = height,
    style      = "minimal",
    border     = BORDER,
    title      = make_title(nil, nil),
    title_pos  = "center",
    noautocmd  = true,
  })

  vim.api.nvim_set_option_value("cursorline",  true,          { win = win })
  vim.api.nvim_set_option_value("wrap",        false,         { win = win })
  vim.api.nvim_set_option_value("winhl",
    "Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual",
    { win = win })

  bind_keys(buf, win, bundles, nil, nil, opts)
  return win
end

return M
