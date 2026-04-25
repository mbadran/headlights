local bundler = require("headlights.bundler")

describe("headlights.bundler", function()
  describe("bundle_name_from_path()", function()
    it("extracts name from vim-plug style path", function()
      local name = bundler.bundle_name_from_path("/home/user/.vim/plugged/vim-fugitive/plugin/fugitive.vim")
      assert.are.equal("fugitive", name)
    end)

    it("extracts name from lazy.nvim style path", function()
      local name = bundler.bundle_name_from_path("/home/user/.local/share/nvim/lazy/telescope.nvim/plugin/telescope.vim")
      assert.are.equal("telescope", name)
    end)

    it("extracts name from packer/pack style path", function()
      -- In packer layout pack/packer/start/<plugin>, the "start" dir is the parent.
      -- "nvim-" prefix is stripped by _clean_name, so result is "treesitter".
      local name = bundler.bundle_name_from_path("/home/user/.local/share/nvim/site/pack/packer/start/nvim-treesitter/plugin/nvim-treesitter.vim")
      assert.are.equal("treesitter", name)
    end)

    it("strips nvim- prefix", function()
      local name = bundler.bundle_name_from_path("/home/user/.vim/plugged/nvim-lspconfig/plugin/lspconfig.vim")
      assert.are.equal("lspconfig", name)
    end)

    it("strips .nvim suffix", function()
      local name = bundler.bundle_name_from_path("/home/user/.vim/plugged/telescope.nvim/lua/telescope/init.lua")
      assert.are.equal("telescope", name)
    end)

    it("strips .vim suffix", function()
      local name = bundler.bundle_name_from_path("/home/user/.vim/plugged/fugitive.vim/plugin/fugitive.vim")
      assert.are.equal("fugitive", name)
    end)

    it("handles bundle directory directly", function()
      local name = bundler.bundle_name_from_path("/home/user/.vim/bundle/syntastic/plugin/syntastic.vim")
      assert.are.equal("syntastic", name)
    end)

    it("falls back to filename without extension for unrecognised paths", function()
      local name = bundler.bundle_name_from_path("/usr/share/vim/vim90/plugin/matchparen.vim")
      assert.are.equal("matchparen", name)
    end)
  end)

  describe("bundle_root_from_path()", function()
    it("returns the plugin root for a vim-plug path", function()
      local root = bundler.bundle_root_from_path("/home/user/.vim/plugged/vim-fugitive/plugin/fugitive.vim")
      assert.are.equal("/home/user/.vim/plugged/vim-fugitive", root)
    end)

    it("returns the plugin root for a lazy path", function()
      local root = bundler.bundle_root_from_path("/home/user/.local/share/nvim/lazy/telescope.nvim/lua/telescope/init.lua")
      assert.are.equal("/home/user/.local/share/nvim/lazy/telescope.nvim", root)
    end)

    it("returns path itself when no plugin manager directory found", function()
      local path = "/usr/share/vim/vim90/plugin/matchparen.vim"
      local root = bundler.bundle_root_from_path(path)
      assert.is_string(root)
      assert.are.not_equal("", root)
    end)
  end)

  describe("build_bundles()", function()
    local scripts, commands, mappings_by_mode

    before_each(function()
      scripts = {
        { sid = 1, name = "/home/user/.vim/plugged/vim-fugitive/plugin/fugitive.vim", autoload = 0 },
        { sid = 2, name = "/home/user/.vim/plugged/vim-fugitive/autoload/fugitive.vim", autoload = 1 },
        { sid = 3, name = "/home/user/.vim/plugged/telescope.nvim/plugin/telescope.vim", autoload = 0 },
        { sid = 4, name = "/usr/share/nvim/runtime/plugin/matchparen.vim", autoload = 0 },
      }

      commands = {
        Git    = { name = "Git",    definition = "call fugitive#Git(<args>)", script_id = 1, nargs = "*" },
        Gdiff  = { name = "Gdiff",  definition = "call fugitive#Diff()",      script_id = 1, nargs = "0" },
        Telescope = { name = "Telescope", definition = "lua require('telescope')", script_id = 3, nargs = "*" },
      }

      mappings_by_mode = {
        n = {
          { lhs = "<leader>gs", rhs = ":Gstatus<CR>", sid = 1, desc = "Git status" },
          { lhs = "<leader>ff", rhs = ":Telescope find_files<CR>", sid = 3, desc = "Find files" },
        },
      }
    end)

    it("returns a list of bundles", function()
      local bundles = bundler.build_bundles(scripts, commands, mappings_by_mode)
      assert.is_table(bundles)
      assert.is_true(#bundles > 0)
    end)

    it("groups scripts from the same plugin into one bundle", function()
      local bundles = bundler.build_bundles(scripts, commands, mappings_by_mode)
      local names = {}
      for _, b in ipairs(bundles) do names[b.name] = true end
      -- fugitive has 2 scripts but should be one bundle
      assert.is_true(names["fugitive"] ~= nil)
    end)

    it("assigns commands to the bundle that defined them", function()
      local bundles = bundler.build_bundles(scripts, commands, mappings_by_mode)
      local fugitive_bundle
      for _, b in ipairs(bundles) do
        if b.name == "fugitive" then fugitive_bundle = b end
      end
      assert.is_not_nil(fugitive_bundle)
      assert.are.equal(2, #fugitive_bundle.commands)
      local cmd_names = {}
      for _, c in ipairs(fugitive_bundle.commands) do cmd_names[c.name] = true end
      assert.is_true(cmd_names["Git"])
      assert.is_true(cmd_names["Gdiff"])
    end)

    it("assigns mappings to the bundle that defined them", function()
      local bundles = bundler.build_bundles(scripts, commands, mappings_by_mode)
      local fugitive_bundle
      for _, b in ipairs(bundles) do
        if b.name == "fugitive" then fugitive_bundle = b end
      end
      assert.is_not_nil(fugitive_bundle)
      assert.are.equal(1, #fugitive_bundle.mappings)
      assert.are.equal("<leader>gs", fugitive_bundle.mappings[1].lhs)
    end)

    it("sorts bundles alphabetically by name", function()
      local bundles = bundler.build_bundles(scripts, commands, mappings_by_mode)
      for i = 2, #bundles do
        assert.is_true(bundles[i - 1].name:lower() <= bundles[i].name:lower())
      end
    end)

    it("includes scripts count per bundle", function()
      local bundles = bundler.build_bundles(scripts, commands, mappings_by_mode)
      local fugitive_bundle
      for _, b in ipairs(bundles) do
        if b.name == "fugitive" then fugitive_bundle = b end
      end
      assert.is_not_nil(fugitive_bundle)
      assert.are.equal(2, #fugitive_bundle.scripts)
    end)

    it("commands with script_id 0 are not attached to any bundle", function()
      commands.Unknown = { name = "Unknown", definition = "echo 'hi'", script_id = 0, nargs = "0" }
      local bundles = bundler.build_bundles(scripts, commands, mappings_by_mode)
      local total_cmds = 0
      for _, b in ipairs(bundles) do total_cmds = total_cmds + #b.commands end
      -- Unknown should not be in any bundle
      assert.are.equal(3, total_cmds)
    end)
  end)
end)
