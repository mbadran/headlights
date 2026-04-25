-- These tests run inside a live Neovim process (via plenary), so Vim API is available.
local collector = require("headlights.collector")

describe("headlights.collector", function()
  describe("get_scripts()", function()
    it("returns a list", function()
      local scripts = collector.get_scripts()
      assert.is_table(scripts)
    end)

    it("each entry has sid and name fields", function()
      local scripts = collector.get_scripts()
      -- There should be at least one script loaded (the runtime itself)
      assert.is_true(#scripts > 0)
      local first = scripts[1]
      assert.is_number(first.sid)
      assert.is_string(first.name)
    end)

    it("name fields are non-empty strings", function()
      local scripts = collector.get_scripts()
      for _, s in ipairs(scripts) do
        assert.is_true(#s.name > 0)
      end
    end)
  end)

  describe("get_commands()", function()
    -- Define a test command before querying
    before_each(function()
      vim.api.nvim_create_user_command("HeadlightsTestCmd", function() end, { nargs = 0 })
    end)

    after_each(function()
      pcall(vim.api.nvim_del_user_command, "HeadlightsTestCmd")
    end)

    it("returns a table", function()
      local cmds = collector.get_commands()
      assert.is_table(cmds)
    end)

    it("includes user-defined commands", function()
      local cmds = collector.get_commands()
      assert.is_not_nil(cmds["HeadlightsTestCmd"])
    end)

    it("each command entry has name and script_id fields", function()
      local cmds = collector.get_commands()
      for _, cmd in pairs(cmds) do
        assert.is_string(cmd.name)
        assert.is_number(cmd.script_id)
        break -- just check the first one
      end
    end)
  end)

  describe("get_mappings()", function()
    before_each(function()
      vim.keymap.set("n", "<leader>hltest", "<Nop>", { desc = "headlights test map" })
    end)

    after_each(function()
      pcall(vim.keymap.del, "n", "<leader>hltest")
    end)

    it("returns a list for normal mode", function()
      local maps = collector.get_mappings("n")
      assert.is_table(maps)
    end)

    it("each mapping has lhs and sid fields", function()
      local maps = collector.get_mappings("n")
      assert.is_true(#maps > 0)
      local first = maps[1]
      assert.is_string(first.lhs)
      assert.is_number(first.sid)
    end)

    it("includes the test mapping we defined", function()
      local maps = collector.get_mappings("n")
      local found = false
      for _, m in ipairs(maps) do
        if m.lhs:find("hltest") then found = true; break end
      end
      assert.is_true(found)
    end)
  end)

  describe("get_buf_commands()", function()
    it("returns a table", function()
      local cmds = collector.get_buf_commands()
      assert.is_table(cmds)
    end)
  end)

  describe("get_buf_mappings()", function()
    it("returns a list for normal mode", function()
      local maps = collector.get_buf_mappings("n")
      assert.is_table(maps)
    end)
  end)

  describe("get_abbreviations()", function()
    before_each(function()
      vim.cmd("iabbrev hltestabrv hello_world")
    end)

    after_each(function()
      pcall(vim.cmd, "iunabbrev hltestabrv")
    end)

    it("returns a list", function()
      local abbrevs = collector.get_abbreviations()
      assert.is_table(abbrevs)
    end)

    it("each entry has mode and lhs fields", function()
      local abbrevs = collector.get_abbreviations()
      if #abbrevs > 0 then
        assert.is_string(abbrevs[1].mode)
        assert.is_string(abbrevs[1].lhs)
      end
    end)
  end)

  describe("get_functions()", function()
    it("returns a list", function()
      local funcs = collector.get_functions()
      assert.is_table(funcs)
    end)

    it("entries are strings", function()
      local funcs = collector.get_functions()
      for _, f in ipairs(funcs) do
        assert.is_string(f)
      end
    end)

    it("does not include autoload (hash) functions", function()
      local funcs = collector.get_functions()
      for _, f in ipairs(funcs) do
        assert.is_falsy(f:find("#"))
      end
    end)
  end)
end)
