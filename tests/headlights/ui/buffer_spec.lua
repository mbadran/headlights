local buffer_ui = require("headlights.ui.buffer")

describe("headlights.ui.buffer", function()
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
    -- Close any headlights buffers that were opened
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) then
        local name = vim.api.nvim_buf_get_name(buf)
        if name:find("headlights") then
          pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
      end
    end
  end)

  describe("render_lines()", function()
    it("returns a list of strings", function()
      local lines = buffer_ui.render_lines(sample_bundles, {})
      assert.is_table(lines)
      assert.is_true(#lines > 0)
      for _, l in ipairs(lines) do
        assert.is_string(l)
      end
    end)

    it("includes a header line", function()
      local lines = buffer_ui.render_lines(sample_bundles, {})
      local found = false
      for _, l in ipairs(lines) do
        if l:lower():find("headlights") then found = true; break end
      end
      assert.is_true(found)
    end)

    it("includes each bundle name", function()
      local lines = buffer_ui.render_lines(sample_bundles, {})
      local text = table.concat(lines, "\n")
      assert.is_truthy(text:find("fugitive"))
      assert.is_truthy(text:find("telescope"))
    end)

    it("includes command names when show_commands is true", function()
      local lines = buffer_ui.render_lines(sample_bundles, { show_commands = true })
      local text = table.concat(lines, "\n")
      assert.is_truthy(text:find("Git"))
      assert.is_truthy(text:find("Gdiff"))
    end)

    it("omits commands when show_commands is false", function()
      -- When explicitly disabled, commands section should not appear
      local bundles_no_cmds = { sample_bundles[1] }
      local lines = buffer_ui.render_lines(bundles_no_cmds, { show_commands = false })
      local text = table.concat(lines, "\n")
      assert.is_falsy(text:find(":Git"))
    end)

    it("includes mapping lhs when show_mappings is true", function()
      local lines = buffer_ui.render_lines(sample_bundles, { show_mappings = true })
      local text = table.concat(lines, "\n")
      assert.is_truthy(text:find("<leader>gs"))
    end)

    it("produces more lines for more bundles", function()
      local lines_one = buffer_ui.render_lines({ sample_bundles[1] }, {})
      local lines_two = buffer_ui.render_lines(sample_bundles, {})
      assert.is_true(#lines_two > #lines_one)
    end)
  end)

  describe("open()", function()
    it("creates a new buffer", function()
      local buf_count_before = #vim.api.nvim_list_bufs()
      buffer_ui.open(sample_bundles, {})
      local buf_count_after = #vim.api.nvim_list_bufs()
      assert.is_true(buf_count_after > buf_count_before)
    end)

    it("returns a buffer number", function()
      local buf = buffer_ui.open(sample_bundles, {})
      assert.is_number(buf)
      assert.is_true(buf > 0)
    end)

    it("the opened buffer is not modifiable", function()
      local buf = buffer_ui.open(sample_bundles, {})
      assert.is_false(vim.api.nvim_get_option_value("modifiable", { buf = buf }))
    end)

    it("the opened buffer has a headlights name", function()
      local buf = buffer_ui.open(sample_bundles, {})
      local name = vim.api.nvim_buf_get_name(buf)
      assert.is_truthy(name:find("headlights"))
    end)

    it("the buffer contains rendered lines", function()
      local buf = buffer_ui.open(sample_bundles, {})
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert.is_true(#lines > 0)
    end)
  end)
end)
