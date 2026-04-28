-- mini.test suite for headlights.collector
-- Live-API tests; require Neovim runtime.

local collector = require("headlights.collector")

local T   = MiniTest.new_set()
local eq  = MiniTest.expect.equality

T["get_scripts()"] = MiniTest.new_set()
T["get_scripts()"]["returns a list"] = function()
  eq(type(collector.get_scripts()), "table")
end
T["get_scripts()"]["entries have sid + name"] = function()
  local scripts = collector.get_scripts()
  MiniTest.expect.equality(#scripts > 0, true)
  eq(type(scripts[1].sid), "number")
  eq(type(scripts[1].name), "string")
end
T["get_scripts()"]["names are non-empty"] = function()
  for _, s in ipairs(collector.get_scripts()) do
    MiniTest.expect.equality(#s.name > 0, true)
  end
end

T["get_commands()"] = MiniTest.new_set({
  hooks = {
    pre_case  = function() vim.api.nvim_create_user_command("HeadlightsTestCmd", function() end, { nargs = 0 }) end,
    post_case = function() pcall(vim.api.nvim_del_user_command, "HeadlightsTestCmd") end,
  },
})
T["get_commands()"]["returns a table"] = function()
  eq(type(collector.get_commands()), "table")
end
T["get_commands()"]["includes user-defined command"] = function()
  MiniTest.expect.no_equality(collector.get_commands()["HeadlightsTestCmd"], nil)
end
T["get_commands()"]["entries have name + script_id"] = function()
  for _, cmd in pairs(collector.get_commands()) do
    eq(type(cmd.name), "string")
    eq(type(cmd.script_id), "number")
    return
  end
end

T["get_mappings()"] = MiniTest.new_set({
  hooks = {
    pre_case  = function() vim.keymap.set("n", "<leader>hltest", "<Nop>", { desc = "headlights test map" }) end,
    post_case = function() pcall(vim.keymap.del, "n", "<leader>hltest") end,
  },
})
T["get_mappings()"]["returns a list for normal mode"] = function()
  eq(type(collector.get_mappings("n")), "table")
end
T["get_mappings()"]["entries have lhs + sid"] = function()
  local maps = collector.get_mappings("n")
  MiniTest.expect.equality(#maps > 0, true)
  eq(type(maps[1].lhs), "string")
  eq(type(maps[1].sid), "number")
end
T["get_mappings()"]["includes the test mapping"] = function()
  local found = false
  for _, m in ipairs(collector.get_mappings("n")) do
    if m.lhs:find("hltest") then found = true; break end
  end
  eq(found, true)
end

T["get_buf_commands()"] = function() eq(type(collector.get_buf_commands()), "table") end
T["get_buf_mappings()"] = function() eq(type(collector.get_buf_mappings("n")), "table") end

T["get_abbreviations()"] = MiniTest.new_set({
  hooks = {
    pre_case  = function() vim.cmd("iabbrev hltestabrv hello_world") end,
    post_case = function() pcall(vim.cmd, "iunabbrev hltestabrv") end,
  },
})
T["get_abbreviations()"]["returns a list"] = function()
  eq(type(collector.get_abbreviations()), "table")
end
T["get_abbreviations()"]["entries have mode + lhs when present"] = function()
  local ab = collector.get_abbreviations()
  if #ab > 0 then
    eq(type(ab[1].mode), "string")
    eq(type(ab[1].lhs),  "string")
  end
end

T["get_functions()"] = MiniTest.new_set()
T["get_functions()"]["returns a list"] = function() eq(type(collector.get_functions()), "table") end
T["get_functions()"]["entries are strings"] = function()
  for _, f in ipairs(collector.get_functions()) do eq(type(f), "string") end
end
T["get_functions()"]["does not include autoload (hash) functions"] = function()
  for _, f in ipairs(collector.get_functions()) do
    MiniTest.expect.equality(f:find("#") == nil, true)
  end
end

return T
