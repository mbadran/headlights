local config = require("headlights.config")

describe("headlights.config", function()
  before_each(function()
    config.setup({})
  end)

  describe("defaults", function()
    it("enables commands by default", function()
      assert.is_true(config.options.show_commands)
    end)

    it("enables mappings by default", function()
      assert.is_true(config.options.show_mappings)
    end)

    it("disables abbreviations by default", function()
      assert.is_false(config.options.show_abbreviations)
    end)

    it("disables functions by default", function()
      assert.is_false(config.options.show_functions)
    end)

    it("disables highlights by default", function()
      assert.is_false(config.options.show_highlights)
    end)

    it("disables files by default", function()
      assert.is_false(config.options.show_files)
    end)

    it("enables smart_menus by default", function()
      assert.is_true(config.options.smart_menus)
    end)

    it("disables load order display by default", function()
      assert.is_false(config.options.show_load_order)
    end)

    it("has a positive menu_width default", function()
      assert.is_true(config.options.menu_width > 0)
    end)
  end)

  describe("setup()", function()
    it("merges user options with defaults", function()
      config.setup({ show_abbreviations = true })
      assert.is_true(config.options.show_abbreviations)
      -- unchanged defaults remain
      assert.is_true(config.options.show_commands)
    end)

    it("allows overriding show_commands", function()
      config.setup({ show_commands = false })
      assert.is_false(config.options.show_commands)
    end)

    it("allows overriding multiple options at once", function()
      config.setup({ show_functions = true, show_highlights = true, show_files = true })
      assert.is_true(config.options.show_functions)
      assert.is_true(config.options.show_highlights)
      assert.is_true(config.options.show_files)
    end)

    it("resets to defaults when called with empty table", function()
      config.setup({ show_commands = false })
      config.setup({})
      assert.is_true(config.options.show_commands)
    end)

    it("accepts nil and behaves as empty table", function()
      config.setup(nil)
      assert.is_true(config.options.show_commands)
    end)
  end)
end)
