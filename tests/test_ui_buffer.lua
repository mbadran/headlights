-- mini.test suite for headlights.ui.buffer

local buffer_ui = require("headlights.ui.buffer")

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
        { name = "Git",   definition = "fugitive#Git(<args>)", nargs = "*" },
        { name = "Gdiff", definition = "fugitive#Diff()",      nargs = "0" },
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

local cleanup_hooks = {
  post_case = function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) then
        local n = vim.api.nvim_buf_get_name(buf)
        if n:find("headlights") then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
      end
    end
  end,
}

T["render_lines()"] = MiniTest.new_set()

T["render_lines()"]["returns a list of strings"] = function()
  local lines = buffer_ui.render_lines(sample(), {})
  eq(type(lines), "table")
  MiniTest.expect.equality(#lines > 0, true)
  for _, l in ipairs(lines) do eq(type(l), "string") end
end

T["render_lines()"]["includes a header"] = function()
  local text = table.concat(buffer_ui.render_lines(sample(), {}), "\n")
  MiniTest.expect.equality(text:lower():find("headlights") ~= nil, true)
end

T["render_lines()"]["includes each plugin name"] = function()
  local text = table.concat(buffer_ui.render_lines(sample(), {}), "\n")
  MiniTest.expect.equality(text:find("fugitive") ~= nil, true)
  MiniTest.expect.equality(text:find("telescope") ~= nil, true)
end

T["render_lines()"]["renders commands when show_commands"] = function()
  local text = table.concat(buffer_ui.render_lines(sample(), { show_commands = true }), "\n")
  MiniTest.expect.equality(text:find(":Git") ~= nil, true)
  MiniTest.expect.equality(text:find(":Gdiff") ~= nil, true)
end

T["render_lines()"]["omits commands when show_commands=false"] = function()
  local single = { sample()[1] }
  local text = table.concat(buffer_ui.render_lines(single, { show_commands = false, show_mappings = true }), "\n")
  MiniTest.expect.equality(text:find(":Git") == nil, true)
end

T["render_lines()"]["renders mappings when show_mappings"] = function()
  local text = table.concat(buffer_ui.render_lines(sample(), { show_mappings = true }), "\n")
  MiniTest.expect.equality(text:find("<leader>gs") ~= nil, true)
end

T["render_lines()"]["produces more lines for more plugins"] = function()
  local one = #buffer_ui.render_lines({ sample()[1] }, {})
  local two = #buffer_ui.render_lines(sample(), {})
  MiniTest.expect.equality(two > one, true)
end

T["render_markdown()"] = MiniTest.new_set()
T["render_markdown()"]["produces a Markdown header and tables"] = function()
  local md = table.concat(buffer_ui.render_markdown(sample(), { show_commands = true }), "\n")
  MiniTest.expect.equality(md:find("^# headlights") ~= nil, true)
  MiniTest.expect.equality(md:find("| Command |") ~= nil, true)
end

T["render_json()"] = MiniTest.new_set()
T["render_json()"]["produces parseable JSON with .plugins"] = function()
  local s = buffer_ui.render_json(sample(), { show_commands = true })[1]
  local ok, decoded = pcall(vim.json.decode, s)
  eq(ok, true)
  eq(type(decoded.plugins), "table")
  MiniTest.expect.equality(#decoded.plugins >= 1, true)
end

T["open()"] = MiniTest.new_set(cleanup_hooks)

T["open()"]["creates a new buffer"] = function()
  local before = #vim.api.nvim_list_bufs()
  buffer_ui.open(sample(), {})
  local after = #vim.api.nvim_list_bufs()
  MiniTest.expect.equality(after > before, true)
end

T["open()"]["returns a buffer number"] = function()
  local buf = buffer_ui.open(sample(), {})
  eq(type(buf), "number")
  MiniTest.expect.equality(buf > 0, true)
end

T["open()"]["buffer is not modifiable"] = function()
  local buf = buffer_ui.open(sample(), {})
  eq(vim.api.nvim_get_option_value("modifiable", { buf = buf }), false)
end

T["open()"]["buffer name contains 'headlights'"] = function()
  local buf = buffer_ui.open(sample(), {})
  MiniTest.expect.equality(vim.api.nvim_buf_get_name(buf):find("headlights") ~= nil, true)
end

T["open()"]["buffer has rendered lines"] = function()
  local buf = buffer_ui.open(sample(), {})
  MiniTest.expect.equality(#vim.api.nvim_buf_get_lines(buf, 0, -1, false) > 0, true)
end

return T
