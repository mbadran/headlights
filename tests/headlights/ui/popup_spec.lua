local popup_ui = require("headlights.ui.popup")

describe("headlights.ui.popup", function()
  local sample_bundles

  before_each(function()
    sample_bundles = {
      {
        name = "fugitive",
        scripts = {
          { sid = 1, name = "/home/user/.vim/plugged/vim-fugitive/plugin/fugitive.vim", autoload = 0 },
        },
        commands = {
          { name = "Git",   definition = "call fugitive#Git(<args>)", nargs = "*" },
          { name = "Gdiff", definition = "call fugitive#Diff()",      nargs = "0" },
        },
        mappings = {
          { mode = "n", lhs = "<leader>gs", rhs = ":Gstatus<CR>", desc = "Git status" },
        },
        abbreviations = {},
        functions = {},
        highlights = {},
      },
      {
        name = "telescope",
        scripts = {
          { sid = 3, name = "/home/user/.vim/plugged/telescope.nvim/plugin/telescope.vim", autoload = 0 },
        },
        commands = {
          { name = "Telescope", definition = "lua require('telescope')", nargs = "*" },
        },
        mappings = {},
        abbreviations = {},
        functions = {},
        highlights = {},
      },
    }
  end)

  after_each(function()
    -- Close any floating windows left open
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(win) then
        local cfg = vim.api.nvim_win_get_config(win)
        if cfg.relative ~= "" then
          pcall(vim.api.nvim_win_close, win, true)
        end
      end
    end
  end)

  describe("build_menu_lines()", function()
    it("returns a list of strings for bundle list", function()
      local lines, entries = popup_ui.build_menu_lines(sample_bundles, nil, nil, {})
      assert.is_table(lines)
      assert.is_table(entries)
      assert.is_true(#lines > 0)
    end)

    it("each line is a string", function()
      local lines = popup_ui.build_menu_lines(sample_bundles, nil, nil, {})
      for _, l in ipairs(lines) do
        assert.is_string(l)
      end
    end)

    it("bundle list contains each bundle name", function()
      local lines = popup_ui.build_menu_lines(sample_bundles, nil, nil, {})
      local text = table.concat(lines, "\n")
      assert.is_truthy(text:find("fugitive"))
      assert.is_truthy(text:find("telescope"))
    end)

    it("category lines are returned when a bundle is selected", function()
      local lines = popup_ui.build_menu_lines(sample_bundles, sample_bundles[1], nil, { show_commands = true })
      local text = table.concat(lines, "\n")
      assert.is_truthy(text:lower():find("command"))
    end)

    it("item lines are returned when bundle and category are selected", function()
      local lines = popup_ui.build_menu_lines(sample_bundles, sample_bundles[1], "commands", { show_commands = true })
      local text = table.concat(lines, "\n")
      assert.is_truthy(text:find("Git"))
    end)
  end)

  describe("open()", function()
    it("opens a floating window", function()
      local wins_before = vim.tbl_filter(function(w)
        return vim.api.nvim_win_get_config(w).relative ~= ""
      end, vim.api.nvim_list_wins())

      popup_ui.open(sample_bundles, {})

      local wins_after = vim.tbl_filter(function(w)
        return vim.api.nvim_win_get_config(w).relative ~= ""
      end, vim.api.nvim_list_wins())

      assert.is_true(#wins_after > #wins_before)
    end)

    it("returns a window handle", function()
      local win = popup_ui.open(sample_bundles, {})
      assert.is_number(win)
      assert.is_true(vim.api.nvim_win_is_valid(win))
    end)

    it("the popup buffer has a keybinding to close", function()
      local win = popup_ui.open(sample_bundles, {})
      local buf = vim.api.nvim_win_get_buf(win)
      local maps = vim.api.nvim_buf_get_keymap(buf, "n")
      local has_quit = false
      for _, m in ipairs(maps) do
        if m.lhs == "q" or m.lhs == "<Esc>" then has_quit = true; break end
      end
      assert.is_true(has_quit)
    end)
  end)
end)
