-- mini.test suite for headlights.config

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      package.loaded["headlights.config"] = nil
      require("headlights.config").setup({})
    end,
  },
})

local eq = MiniTest.expect.equality

T["defaults"] = MiniTest.new_set()

T["defaults"]["enables commands"]      = function() eq(require("headlights.config").options.show_commands, true) end
T["defaults"]["enables mappings"]      = function() eq(require("headlights.config").options.show_mappings, true) end
T["defaults"]["disables abbreviations"] = function() eq(require("headlights.config").options.show_abbreviations, false) end
T["defaults"]["disables functions"]    = function() eq(require("headlights.config").options.show_functions, false) end
T["defaults"]["disables highlights"]   = function() eq(require("headlights.config").options.show_highlights, false) end
T["defaults"]["disables files"]        = function() eq(require("headlights.config").options.show_files, false) end
T["defaults"]["disables autocmds"]     = function() eq(require("headlights.config").options.show_autocmds, false) end
T["defaults"]["disables signs"]        = function() eq(require("headlights.config").options.show_signs, false) end
T["defaults"]["enables smart_menus"]   = function() eq(require("headlights.config").options.smart_menus, true) end
T["defaults"]["disables show_load_order"] = function() eq(require("headlights.config").options.show_load_order, false) end
T["defaults"]["positive menu_width"]   = function()
  MiniTest.expect.equality(require("headlights.config").options.menu_width > 0, true)
end
T["defaults"]["extra_plugin_dirs is empty list"] = function()
  eq(type(require("headlights.config").options.extra_plugin_dirs), "table")
  eq(#require("headlights.config").options.extra_plugin_dirs, 0)
end

T["setup()"] = MiniTest.new_set()

T["setup()"]["merges user options with defaults"] = function()
  local config = require("headlights.config")
  config.setup({ show_abbreviations = true })
  eq(config.options.show_abbreviations, true)
  eq(config.options.show_commands, true)
end

T["setup()"]["allows overriding show_commands"] = function()
  local config = require("headlights.config")
  config.setup({ show_commands = false })
  eq(config.options.show_commands, false)
end

T["setup()"]["allows overriding multiple options at once"] = function()
  local config = require("headlights.config")
  config.setup({ show_functions = true, show_highlights = true, show_files = true })
  eq(config.options.show_functions, true)
  eq(config.options.show_highlights, true)
  eq(config.options.show_files, true)
end

T["setup()"]["resets to defaults when called with empty table"] = function()
  local config = require("headlights.config")
  config.setup({ show_commands = false })
  config.setup({})
  eq(config.options.show_commands, true)
end

T["setup()"]["accepts nil and behaves as empty table"] = function()
  local config = require("headlights.config")
  config.setup(nil)
  eq(config.options.show_commands, true)
end

T["setup()"]["accepts extra_plugin_dirs as a list of patterns"] = function()
  local config = require("headlights.config")
  config.setup({ extra_plugin_dirs = { "^(/nix/store/[^/]+%-([^/]+))/" } })
  eq(#config.options.extra_plugin_dirs, 1)
end

return T
