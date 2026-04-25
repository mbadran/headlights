-- Integration tests: "before and after" plugin lifecycle.
--
-- These tests SOURCE a real Vim script fixture (tests/fixtures/test_plugin.vim)
-- and then verify that headlights discovers and correctly attributes its
-- commands, mappings, and abbreviations.
--
-- This simulates the real-world scenario of a plugin being installed and
-- loaded, without needing to actually install a third-party package.

local collector = require("headlights.collector")
local bundler   = require("headlights.bundler")

local FIXTURE = vim.fn.getcwd() .. "/tests/fixtures/test_plugin.vim"

-- -------------------------------------------------------------------------
-- Helpers
-- -------------------------------------------------------------------------

local function find_fixture_sid()
  for _, s in ipairs(collector.get_scripts()) do
    if s.name:find("test_plugin.vim", 1, true) then return s.sid end
  end
end

local function build(extra_cmds, extra_maps)
  local snap    = collector.snapshot()
  -- Merge any extra commands/mappings for targeted tests
  for k, v in pairs(extra_cmds or {}) do snap.commands[k] = v end
  for mode, list in pairs(extra_maps or {}) do
    snap.mappings[mode] = snap.mappings[mode] or {}
    for _, m in ipairs(list) do table.insert(snap.mappings[mode], m) end
  end
  return bundler.build_bundles(snap.scripts, snap.commands, snap.mappings)
end

local function bundle_for_sid(sid)
  for _, b in ipairs(build()) do
    for _, s in ipairs(b.scripts) do
      if s.sid == sid then return b end
    end
  end
end

-- -------------------------------------------------------------------------
-- BASELINE: before the fixture is loaded
-- -------------------------------------------------------------------------

describe("baseline — no fixture loaded", function()
  it("snapshot() runs without error", function()
    assert.has_no.errors(function() collector.snapshot() end)
  end)

  it("build_bundles() handles empty input gracefully", function()
    local bundles = bundler.build_bundles({}, {}, {})
    assert.are.equal(0, #bundles)
  end)

  it("fixture commands are absent before sourcing", function()
    assert.is_nil(collector.get_commands()["HeadlightsFixtureCmd"])
  end)

  it("collector returns a list of scripts", function()
    local scripts = collector.get_scripts()
    assert.is_table(scripts)
    assert.is_true(#scripts > 0)
  end)
end)

-- -------------------------------------------------------------------------
-- AFTER LOAD: source the fixture, then verify discovery
-- -------------------------------------------------------------------------

describe("after sourcing test_plugin.vim fixture", function()
  local fixture_sid

  before_each(function()
    vim.cmd("source " .. FIXTURE)
    fixture_sid = find_fixture_sid()
  end)

  after_each(function()
    pcall(vim.api.nvim_del_user_command, "HeadlightsFixtureCmd")
    pcall(vim.api.nvim_del_user_command, "HeadlightsFixtureCmd2")
    pcall(vim.keymap.del, "n", "<leader>HLfx")
    pcall(vim.keymap.del, "i", "<C-HLfx>")
    pcall(vim.cmd, "silent! iunabbrev HLfxabrv")
  end)

  -- -----------------------------------------------------------------------
  -- Collector-level assertions
  -- -----------------------------------------------------------------------

  describe("collector", function()
    it("discovers the fixture script", function()
      assert.is_not_nil(fixture_sid,
        "test_plugin.vim not found in getscriptinfo()")
    end)

    it("discovers HeadlightsFixtureCmd", function()
      assert.is_not_nil(collector.get_commands()["HeadlightsFixtureCmd"])
    end)

    it("fixture command carries the fixture script_id", function()
      if not fixture_sid then pending("fixture not loaded"); return end
      local cmd = collector.get_commands()["HeadlightsFixtureCmd"]
      assert.is_not_nil(cmd)
      assert.are.equal(fixture_sid, cmd.script_id)
    end)

    it("discovers the normal-mode fixture mapping", function()
      local found = false
      for _, m in ipairs(collector.get_mappings("n")) do
        if m.lhs:find("HLfx") then found = true; break end
      end
      assert.is_true(found, "fixture normal mapping not in get_mappings('n')")
    end)

    it("discovers the insert-mode fixture mapping", function()
      local found = false
      for _, m in ipairs(collector.get_mappings("i")) do
        if m.lhs:find("HLfx") then found = true; break end
      end
      assert.is_true(found, "fixture insert mapping not in get_mappings('i')")
    end)

    it("discovers the fixture abbreviation", function()
      local abbrevs = collector.get_abbreviations()
      local found   = false
      for _, a in ipairs(abbrevs) do
        if a.lhs == "HLfxabrv" then found = true; break end
      end
      assert.is_true(found, "fixture abbreviation not found")
    end)
  end)

  -- -----------------------------------------------------------------------
  -- Bundler-level assertions
  -- -----------------------------------------------------------------------

  describe("bundler", function()
    it("creates a bundle that owns the fixture script", function()
      if not fixture_sid then pending("fixture not loaded"); return end
      assert.is_not_nil(bundle_for_sid(fixture_sid),
        "no bundle found for fixture sid " .. tostring(fixture_sid))
    end)

    it("attributes HeadlightsFixtureCmd to the fixture bundle", function()
      if not fixture_sid then pending("fixture not loaded"); return end
      local b = bundle_for_sid(fixture_sid)
      assert.is_not_nil(b)
      local names = {}
      for _, c in ipairs(b.commands) do names[c.name] = true end
      assert.is_true(names["HeadlightsFixtureCmd"],
        "HeadlightsFixtureCmd not attributed to fixture bundle")
    end)

    it("attributes HeadlightsFixtureCmd2 to the fixture bundle", function()
      if not fixture_sid then pending("fixture not loaded"); return end
      local b = bundle_for_sid(fixture_sid)
      assert.is_not_nil(b)
      local names = {}
      for _, c in ipairs(b.commands) do names[c.name] = true end
      assert.is_true(names["HeadlightsFixtureCmd2"],
        "HeadlightsFixtureCmd2 not attributed to fixture bundle")
    end)

    it("attributes the fixture normal-mode mapping to the fixture bundle", function()
      if not fixture_sid then pending("fixture not loaded"); return end
      local b = bundle_for_sid(fixture_sid)
      assert.is_not_nil(b)
      local found = false
      for _, m in ipairs(b.mappings) do
        if m.lhs:find("HLfx") and m.mode == "n" then found = true; break end
      end
      assert.is_true(found, "fixture normal mapping not attributed to bundle")
    end)

    it("bundle has correct script count for fixture", function()
      if not fixture_sid then pending("fixture not loaded"); return end
      local b = bundle_for_sid(fixture_sid)
      assert.is_not_nil(b)
      -- The fixture is a single .vim file
      assert.are.equal(1, #b.scripts)
    end)
  end)

  -- -----------------------------------------------------------------------
  -- End-to-end: UI rendering sees the fixture resources
  -- -----------------------------------------------------------------------

  describe("UI rendering", function()
    it("buffer UI includes HeadlightsFixtureCmd in output", function()
      local buf_ui = require("headlights.ui.buffer")
      local bundles = build()
      local text    = table.concat(buf_ui.render_lines(bundles, { show_commands = true }), "\n")
      assert.is_truthy(text:find("HeadlightsFixtureCmd"),
        "buffer UI did not render fixture command")
    end)

    it("popup UI bundle list is non-empty after fixture load", function()
      local popup_ui = require("headlights.ui.popup")
      local bundles  = build()
      local lines, entries = popup_ui.build_menu_lines(bundles, nil, nil, {})
      assert.is_true(#entries > 0, "popup bundle list is empty after fixture load")
    end)

    it("popup command list includes fixture commands when bundle selected", function()
      if not fixture_sid then pending("fixture not loaded"); return end
      local popup_ui   = require("headlights.ui.popup")
      local b          = bundle_for_sid(fixture_sid)
      assert.is_not_nil(b)
      local lines, _   = popup_ui.build_menu_lines({}, b, "commands", {})
      local text       = table.concat(lines, "\n")
      assert.is_truthy(text:find("HeadlightsFixtureCmd"),
        "popup command level did not show fixture command")
    end)
  end)
end)
