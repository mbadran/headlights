-- mini.test suite for headlights.bundler — pure-logic tests, no Vim API.

local bundler = require("headlights.bundler")

local T  = MiniTest.new_set()
local eq = MiniTest.expect.equality

-- --------------------------------------------------------------------------
T["bundle_name_from_path()"] = MiniTest.new_set()

T["bundle_name_from_path()"]["vim-plug path"] = function()
  eq(bundler.bundle_name_from_path("/home/user/.vim/plugged/vim-fugitive/plugin/fugitive.vim"), "fugitive")
end
T["bundle_name_from_path()"]["lazy.nvim path"] = function()
  eq(bundler.bundle_name_from_path("/home/user/.local/share/nvim/lazy/telescope.nvim/plugin/telescope.vim"), "telescope")
end
T["bundle_name_from_path()"]["packer/pack path"] = function()
  eq(bundler.bundle_name_from_path("/home/user/.local/share/nvim/site/pack/packer/start/nvim-treesitter/plugin/nvim-treesitter.vim"), "treesitter")
end
T["bundle_name_from_path()"]["strips nvim- prefix"] = function()
  eq(bundler.bundle_name_from_path("/home/user/.vim/plugged/nvim-lspconfig/plugin/lspconfig.vim"), "lspconfig")
end
T["bundle_name_from_path()"]["strips .nvim suffix"] = function()
  eq(bundler.bundle_name_from_path("/home/user/.vim/plugged/telescope.nvim/lua/telescope/init.lua"), "telescope")
end
T["bundle_name_from_path()"]["strips .vim suffix"] = function()
  eq(bundler.bundle_name_from_path("/home/user/.vim/plugged/fugitive.vim/plugin/fugitive.vim"), "fugitive")
end
T["bundle_name_from_path()"]["bundle directory directly"] = function()
  eq(bundler.bundle_name_from_path("/home/user/.vim/bundle/syntastic/plugin/syntastic.vim"), "syntastic")
end
T["bundle_name_from_path()"]["filename fallback for unknown layout"] = function()
  eq(bundler.bundle_name_from_path("/usr/share/vim/vim90/plugin/matchparen.vim"), "matchparen")
end

-- --------------------------------------------------------------------------
T["bundle_root_from_path()"] = MiniTest.new_set()

T["bundle_root_from_path()"]["vim-plug root"] = function()
  eq(bundler.bundle_root_from_path("/home/user/.vim/plugged/vim-fugitive/plugin/fugitive.vim"),
     "/home/user/.vim/plugged/vim-fugitive")
end
T["bundle_root_from_path()"]["lazy root"] = function()
  eq(bundler.bundle_root_from_path("/home/user/.local/share/nvim/lazy/telescope.nvim/lua/telescope/init.lua"),
     "/home/user/.local/share/nvim/lazy/telescope.nvim")
end
T["bundle_root_from_path()"]["fallback returns a non-empty string"] = function()
  local root = bundler.bundle_root_from_path("/usr/share/vim/vim90/plugin/matchparen.vim")
  eq(type(root), "string")
  MiniTest.expect.equality(#root > 0, true)
end

-- --------------------------------------------------------------------------
T["bundle_root_from_path() with extra_plugin_dirs"] = MiniTest.new_set()

T["bundle_root_from_path() with extra_plugin_dirs"]["nix store grouping"] = function()
  local extra  = { "^(/nix/store/[^/]+%-([^/]+))/" }
  local root, name = bundler.bundle_root_from_path(
    "/nix/store/abc123-vim-fugitive-3.7/plugin/fugitive.vim", extra)
  eq(root, "/nix/store/abc123-vim-fugitive-3.7")
  eq(name, "vim-fugitive-3.7")
end

T["bundle_root_from_path() with extra_plugin_dirs"]["custom dir grouping"] = function()
  local extra  = { "^(.*/myplugins/([^/]+))/" }
  local root, name = bundler.bundle_root_from_path(
    "/home/u/.config/nvim/myplugins/special-plugin/plugin/init.vim", extra)
  eq(root, "/home/u/.config/nvim/myplugins/special-plugin")
  eq(name, "special-plugin")
end

-- --------------------------------------------------------------------------
T["build_bundles()"] = MiniTest.new_set()

local function fixture()
  return
    {
      { sid = 1, name = "/home/user/.vim/plugged/vim-fugitive/plugin/fugitive.vim",   autoload = 0 },
      { sid = 2, name = "/home/user/.vim/plugged/vim-fugitive/autoload/fugitive.vim", autoload = 1 },
      { sid = 3, name = "/home/user/.vim/plugged/telescope.nvim/plugin/telescope.vim", autoload = 0 },
      { sid = 4, name = "/usr/share/nvim/runtime/plugin/matchparen.vim",               autoload = 0 },
    },
    {
      Git       = { name = "Git",       definition = "fugitive#Git()",       script_id = 1, nargs = "*" },
      Gdiff     = { name = "Gdiff",     definition = "fugitive#Diff()",      script_id = 1, nargs = "0" },
      Telescope = { name = "Telescope", definition = "lua require('tele')",  script_id = 3, nargs = "*" },
    },
    {
      n = {
        { lhs = "<leader>gs", rhs = ":Gstatus<CR>",            sid = 1, desc = "Git status"  },
        { lhs = "<leader>ff", rhs = ":Telescope find_files<CR>", sid = 3, desc = "Find files" },
      },
    }
end

T["build_bundles()"]["returns a non-empty list"] = function()
  local s, c, m = fixture()
  local b = bundler.build_bundles(s, c, m)
  eq(type(b), "table")
  MiniTest.expect.equality(#b > 0, true)
end

T["build_bundles()"]["groups same-plugin scripts"] = function()
  local s, c, m = fixture()
  local b = bundler.build_bundles(s, c, m)
  local names = {}
  for _, x in ipairs(b) do names[x.name] = true end
  eq(names["fugitive"], true)
end

T["build_bundles()"]["assigns commands by script_id"] = function()
  local s, c, m = fixture()
  local b = bundler.build_bundles(s, c, m)
  local fug
  for _, x in ipairs(b) do if x.name == "fugitive" then fug = x end end
  eq(#fug.commands, 2)
end

T["build_bundles()"]["assigns mappings by sid"] = function()
  local s, c, m = fixture()
  local b = bundler.build_bundles(s, c, m)
  local fug
  for _, x in ipairs(b) do if x.name == "fugitive" then fug = x end end
  eq(#fug.mappings, 1)
  eq(fug.mappings[1].lhs, "<leader>gs")
end

T["build_bundles()"]["sorts bundles alphabetically"] = function()
  local s, c, m = fixture()
  local b = bundler.build_bundles(s, c, m)
  for i = 2, #b do
    MiniTest.expect.equality(b[i - 1].name:lower() <= b[i].name:lower(), true)
  end
end

T["build_bundles()"]["script_id 0 commands are dropped"] = function()
  local s, c, m = fixture()
  c.Unknown = { name = "Unknown", definition = "echo 'hi'", script_id = 0, nargs = "0" }
  local b = bundler.build_bundles(s, c, m)
  local total = 0
  for _, x in ipairs(b) do total = total + #x.commands end
  eq(total, 3)
end

T["build_bundles()"]["accepts extra_plugin_dirs and groups nix paths"] = function()
  local scripts = {
    { sid = 10, name = "/nix/store/abc-myplugin-1.0/plugin/myplugin.vim", autoload = 0 },
    { sid = 11, name = "/nix/store/abc-myplugin-1.0/autoload/myplugin.vim", autoload = 1 },
  }
  local b = bundler.build_bundles(scripts, {}, {}, { "^(/nix/store/[^/]+%-([^/]+))/" })
  eq(#b, 1)
  eq(#b[1].scripts, 2)
end

-- --------------------------------------------------------------------------
T["function attribution"] = MiniTest.new_set()

T["function attribution"]["functions field is honoured"] = function()
  local scripts = {
    {
      sid = 1,
      name = "/home/user/.vim/plugged/vim-fugitive/plugin/fugitive.vim",
      autoload = 0,
      functions = { "fugitive#Git", "FugitiveStatus" },
    },
    {
      sid = 2,
      name = "/home/user/.vim/plugged/telescope.nvim/plugin/telescope.vim",
      autoload = 0,
      functions = { "TelescopeBuiltin" },
    },
  }
  local b = bundler.build_bundles(scripts, {}, {})
  local by_name = {}
  for _, x in ipairs(b) do by_name[x.name] = x end
  eq(#by_name.fugitive.functions, 2)
  eq(#by_name.telescope.functions, 1)
end

-- --------------------------------------------------------------------------
T["abbreviation attribution (#25)"] = MiniTest.new_set()

T["abbreviation attribution (#25)"]["matches by Last set source path"] = function()
  local scripts = {
    { sid = 1, name = "/home/user/.vim/plugged/myabbrev/plugin/myabbrev.vim", autoload = 0 },
  }
  local extras = {
    abbreviations = {
      { mode = "i", lhs = "btw", rhs = "by the way",
        source = "/home/user/.vim/plugged/myabbrev/plugin/myabbrev.vim" },
    },
  }
  local b = bundler.build_bundles(scripts, {}, {}, nil, extras)
  eq(b[1].name, "myabbrev")
  eq(#b[1].abbreviations, 1)
  eq(b[1].abbreviations[1].lhs, "btw")
end

-- --------------------------------------------------------------------------
T["highlight attribution (#25)"] = MiniTest.new_set()

T["highlight attribution (#25)"]["matches by Last set source path"] = function()
  local scripts = {
    { sid = 1, name = "/home/user/.vim/plugged/mycolors/colors/scheme.vim", autoload = 0 },
  }
  local extras = {
    highlights = {
      { name = "MyTheme",
        source = "/home/user/.vim/plugged/mycolors/colors/scheme.vim" },
      { name = "Unattributed", source = nil },
    },
  }
  local b = bundler.build_bundles(scripts, {}, {}, nil, extras)
  eq(b[1].name, "mycolors")
  eq(#b[1].highlights, 1)
  eq(b[1].highlights[1], "MyTheme")
end

-- --------------------------------------------------------------------------
T["autocmd attribution (#26)"] = MiniTest.new_set()

T["autocmd attribution (#26)"]["matches by augroup name"] = function()
  local scripts = {
    { sid = 1, name = "/home/user/.vim/plugged/telescope.nvim/plugin/telescope.vim", autoload = 0 },
  }
  local extras = {
    autocmds = {
      { event = "BufWinEnter", group_name = "TelescopeFindFiles", pattern = "*" },
      { event = "BufWritePre", group_name = "OrphanGroup",        pattern = "*" },
    },
  }
  local bundles, side = bundler.build_bundles(scripts, {}, {}, nil, extras)
  eq(#bundles[1].autocmds, 1)
  eq(bundles[1].autocmds[1].event, "BufWinEnter")
  eq(#side.autocmds, 1)
  eq(side.autocmds[1].group_name, "OrphanGroup")
end

-- --------------------------------------------------------------------------
T["sign attribution"] = MiniTest.new_set()

T["sign attribution"]["matches by name + texthl"] = function()
  local scripts = {
    { sid = 1, name = "/home/user/.vim/plugged/gitsigns.nvim/plugin/gitsigns.vim", autoload = 0 },
  }
  local extras = {
    signs = {
      { name = "GitSignsAdd",    texthl = "GitSignsAdd",    text = "+" },
      { name = "DiagnosticInfo", texthl = "DiagnosticInfo", text = "i" },
    },
  }
  local bundles, side = bundler.build_bundles(scripts, {}, {}, nil, extras)
  eq(#bundles[1].signs, 1)
  eq(bundles[1].signs[1].name, "GitSignsAdd")
  eq(#side.signs, 1)
end

return T
