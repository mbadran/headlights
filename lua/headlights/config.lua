local M = {}

M.defaults = {
  show_commands     = true,
  show_mappings     = true,
  show_abbreviations = false,
  show_functions    = false,
  show_highlights   = false,
  show_files        = false,
  smart_menus       = true,
  show_load_order   = false,
  menu_width        = 60,
  menu_max_height   = 25,
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

-- Initialise with defaults so the module is usable before setup() is called.
M.setup({})

return M
