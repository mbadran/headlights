-- mini.test integration suite — sources a real Vim-script fixture and
-- verifies discovery, attribution, and rendering end-to-end.

local collector = require("headlights.collector")
local bundler   = require("headlights.bundler")

local FIXTURE = vim.fn.getcwd() .. "/tests/fixtures/test_plugin.vim"

local T  = MiniTest.new_set()
local eq = MiniTest.expect.equality

local function find_fixture_sid()
  for _, s in ipairs(collector.get_scripts()) do
    if s.name:find("test_plugin.vim", 1, true) then return s.sid end
  end
end

local function build()
  local snap = collector.snapshot()
  return bundler.build_bundles(snap.scripts, snap.commands, snap.mappings, nil, {
    abbreviations = snap.abbreviations,
    highlights    = snap.highlights,
    autocmds      = snap.autocmds,
    signs         = snap.signs,
  })
end

local function bundle_for_sid(sid)
  for _, b in ipairs(build()) do
    for _, s in ipairs(b.scripts) do
      if s.sid == sid then return b end
    end
  end
end

-- ----------------------------------------------------------------
T["baseline (fixture not loaded)"] = MiniTest.new_set()

T["baseline (fixture not loaded)"]["snapshot() does not error"] = function()
  MiniTest.expect.no_error(function() collector.snapshot() end)
end

T["baseline (fixture not loaded)"]["build_bundles() handles empty input"] = function()
  eq(#bundler.build_bundles({}, {}, {}), 0)
end

T["baseline (fixture not loaded)"]["fixture command absent before sourcing"] = function()
  eq(collector.get_commands()["HeadlightsFixtureCmd"], nil)
end

-- ----------------------------------------------------------------
T["after sourcing fixture"] = MiniTest.new_set({
  hooks = {
    pre_case = function()
      vim.cmd("source " .. FIXTURE)
    end,
    post_case = function()
      pcall(vim.api.nvim_del_user_command, "HeadlightsFixtureCmd")
      pcall(vim.api.nvim_del_user_command, "HeadlightsFixtureCmd2")
      pcall(vim.keymap.del, "n", "<leader>HLfx")
      pcall(vim.keymap.del, "i", "<C-HLfx>")
      pcall(vim.cmd, "silent! iunabbrev HLfxabrv")
      pcall(vim.api.nvim_del_augroup_by_name, "HeadlightsFixtureGroup")
      pcall(vim.fn.sign_undefine, "HeadlightsFixtureSign")
      pcall(vim.cmd, "silent! highlight clear HeadlightsFixtureHL")
    end,
  },
})

T["after sourcing fixture"]["collector finds fixture script"] = function()
  MiniTest.expect.no_equality(find_fixture_sid(), nil)
end

T["after sourcing fixture"]["collector finds HeadlightsFixtureCmd"] = function()
  MiniTest.expect.no_equality(collector.get_commands()["HeadlightsFixtureCmd"], nil)
end

T["after sourcing fixture"]["fixture command carries fixture sid"] = function()
  local sid = find_fixture_sid()
  if not sid then return end
  eq(collector.get_commands()["HeadlightsFixtureCmd"].script_id, sid)
end

T["after sourcing fixture"]["collector finds normal-mode mapping"] = function()
  local found = false
  for _, m in ipairs(collector.get_mappings("n")) do
    if m.lhs:find("HLfx") then found = true; break end
  end
  eq(found, true)
end

T["after sourcing fixture"]["collector finds insert-mode mapping"] = function()
  local found = false
  for _, m in ipairs(collector.get_mappings("i")) do
    if m.lhs:find("HLfx") then found = true; break end
  end
  eq(found, true)
end

T["after sourcing fixture"]["collector finds abbreviation"] = function()
  local found = false
  for _, a in ipairs(collector.get_abbreviations()) do
    if a.lhs == "HLfxabrv" then found = true; break end
  end
  eq(found, true)
end

T["after sourcing fixture"]["bundler creates bundle for fixture"] = function()
  local sid = find_fixture_sid()
  if not sid then return end
  MiniTest.expect.no_equality(bundle_for_sid(sid), nil)
end

T["after sourcing fixture"]["fixture commands attributed to fixture bundle"] = function()
  local sid = find_fixture_sid()
  if not sid then return end
  local b = bundle_for_sid(sid)
  local names = {}
  for _, c in ipairs(b.commands) do names[c.name] = true end
  eq(names["HeadlightsFixtureCmd"],  true)
  eq(names["HeadlightsFixtureCmd2"], true)
end

T["after sourcing fixture"]["normal-mode fixture mapping attributed to bundle"] = function()
  local sid = find_fixture_sid()
  if not sid then return end
  local b = bundle_for_sid(sid)
  local found = false
  for _, m in ipairs(b.mappings) do
    if m.lhs:find("HLfx") and m.mode == "n" then found = true; break end
  end
  eq(found, true)
end

T["after sourcing fixture"]["UI rendering shows fixture command"] = function()
  local buffer_ui = require("headlights.ui.buffer")
  local text = table.concat(buffer_ui.render_lines(build(), { show_commands = true }), "\n")
  MiniTest.expect.equality(text:find("HeadlightsFixtureCmd") ~= nil, true)
end

T["after sourcing fixture"]["popup item-list shows fixture command"] = function()
  local sid = find_fixture_sid()
  if not sid then return end
  local popup_ui = require("headlights.ui.popup")
  local b        = bundle_for_sid(sid)
  local lines, _ = popup_ui.build_menu_lines({}, b, "commands", {})
  local text     = table.concat(lines, "\n")
  MiniTest.expect.equality(text:find("HeadlightsFixtureCmd") ~= nil, true)
end

T["after sourcing fixture"]["fixture augroup autocmd is attributed"] = function()
  local sid = find_fixture_sid()
  if not sid then return end
  local b = bundle_for_sid(sid)
  local found = false
  for _, ac in ipairs(b.autocmds) do
    if (ac.group_name or ac.group or ""):find("HeadlightsFixture") then
      found = true; break
    end
  end
  eq(found, true)
end

T["after sourcing fixture"]["fixture sign is attributed"] = function()
  local sid = find_fixture_sid()
  if not sid then return end
  local b = bundle_for_sid(sid)
  local found = false
  for _, sg in ipairs(b.signs) do
    if (sg.name or ""):find("HeadlightsFixture") then found = true; break end
  end
  eq(found, true)
end

return T
