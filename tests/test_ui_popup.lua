-- mini.test suite for headlights.ui.popup

local popup_ui = require("headlights.ui.popup")

local T  = MiniTest.new_set()
local eq = MiniTest.expect.equality

local function sample()
  return {
    {
      name = "fugitive",
      scripts = {
        { sid = 1, name = "/home/user/.vim/plugged/vim-fugitive/plugin/fugitive.vim", autoload = 0 },
      },
      commands = {
        { name = "Git",   definition = "fugitive#Git()", nargs = "*" },
        { name = "Gdiff", definition = "fugitive#Diff()", nargs = "0" },
      },
      mappings = {
        { mode = "n", lhs = "<leader>gs", rhs = ":Gstatus<CR>", desc = "Git status" },
      },
      abbreviations = {}, functions = {}, highlights = {},
    },
    {
      name = "telescope",
      scripts = {
        { sid = 3, name = "/home/user/.vim/plugged/telescope.nvim/plugin/telescope.vim", autoload = 0 },
      },
      commands = {
        { name = "Telescope", definition = "lua require('telescope')", nargs = "*" },
      },
      mappings = {}, abbreviations = {}, functions = {}, highlights = {},
    },
  }
end

T["build_menu_lines()"] = MiniTest.new_set()

T["build_menu_lines()"]["plugin list, returns lines + entries"] = function()
  local lines, entries = popup_ui.build_menu_lines(sample(), nil, nil, {})
  eq(type(lines), "table")
  eq(type(entries), "table")
  MiniTest.expect.equality(#lines > 0, true)
end

T["build_menu_lines()"]["plugin list contains each name"] = function()
  local lines = popup_ui.build_menu_lines(sample(), nil, nil, {})
  local text = table.concat(lines, "\n")
  MiniTest.expect.equality(text:find("fugitive") ~= nil, true)
  MiniTest.expect.equality(text:find("telescope") ~= nil, true)
end

T["build_menu_lines()"]["category lines for selected plugin"] = function()
  local s = sample()
  local lines = popup_ui.build_menu_lines(s, s[1], nil, { show_commands = true })
  local text = table.concat(lines, "\n")
  MiniTest.expect.equality(text:lower():find("command") ~= nil, true)
end

T["build_menu_lines()"]["item lines for plugin + category"] = function()
  local s = sample()
  local lines = popup_ui.build_menu_lines(s, s[1], "commands", { show_commands = true })
  local text = table.concat(lines, "\n")
  MiniTest.expect.equality(text:find("Git") ~= nil, true)
end

T["open()"] = MiniTest.new_set({
  hooks = {
    post_case = function()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) then
          local cfg = vim.api.nvim_win_get_config(win)
          if cfg.relative ~= "" then pcall(vim.api.nvim_win_close, win, true) end
        end
      end
    end,
  },
})

T["open()"]["opens a floating window"] = function()
  local count_floats = function()
    return #vim.tbl_filter(function(w)
      return vim.api.nvim_win_get_config(w).relative ~= ""
    end, vim.api.nvim_list_wins())
  end
  local before = count_floats()
  popup_ui.open(sample(), {})
  MiniTest.expect.equality(count_floats() > before, true)
end

T["open()"]["returns a window handle"] = function()
  local win = popup_ui.open(sample(), {})
  eq(type(win), "number")
  eq(vim.api.nvim_win_is_valid(win), true)
end

T["open()"]["buffer has q / <Esc> binding"] = function()
  local win = popup_ui.open(sample(), {})
  local buf = vim.api.nvim_win_get_buf(win)
  local maps = vim.api.nvim_buf_get_keymap(buf, "n")
  local has_quit = false
  for _, m in ipairs(maps) do
    if m.lhs == "q" or m.lhs == "<Esc>" then has_quit = true; break end
  end
  eq(has_quit, true)
end

return T
