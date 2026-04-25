local M = {}

-- Ordered list of directory names that plugin managers use as the direct
-- parent of individual plugin folders.
-- NOTE: "packer" is intentionally absent — in packer.nvim the layout is
-- pack/packer/start/<plugin>, so "start" (not "packer") is the parent.
local PLUGIN_MANAGER_DIRS = {
  "plugged",  -- vim-plug
  "bundle",   -- pathogen / Vundle
  "lazy",     -- lazy.nvim
  "start",    -- vim 8 pack + packer.nvim
  "opt",      -- vim 8 pack opt
}

-- Patterns that identify a plugin root inside a plugin-manager parent dir.
-- Captures the root path and the plugin folder name.
local ROOT_PATTERNS = {}
for _, dir in ipairs(PLUGIN_MANAGER_DIRS) do
  -- e.g. /home/user/.vim/plugged/vim-fugitive/...  →  root = .../plugged/vim-fugitive
  table.insert(ROOT_PATTERNS, "^(.*/" .. dir .. "/([^/]+))/")
end
-- Also handle pack/<manager>/start|opt/<plugin>
table.insert(ROOT_PATTERNS, "^(.*/pack/[^/]+/[^/]+/([^/]+))/")

--- Return the filesystem root of the bundle that owns `path`.
--- Falls back to the directory two levels above the file for unknown layouts.
function M.bundle_root_from_path(path)
  for _, pat in ipairs(ROOT_PATTERNS) do
    local root = path:match(pat)
    if root then return root end
  end
  -- Fallback: two directories up from the file
  return path:match("^(.+/[^/]+/[^/]+)/[^/]+$")
      or path:match("^(.+)/[^/]+$")
      or path
end

--- Derive a human-readable bundle name from `path`.
function M.bundle_name_from_path(path)
  -- Try each root pattern to get the raw folder name
  for _, pat in ipairs(ROOT_PATTERNS) do
    local _, folder = path:match(pat)
    if folder then
      return M._clean_name(folder)
    end
  end
  -- Fallback: use the filename without extension
  local filename = path:match("([^/]+)%.[^.]+$") or path:match("([^/]+)$")
  return filename or path
end

--- Strip common plugin-name decorations to get a clean display name.
function M._clean_name(raw)
  local name = raw
  name = name:gsub("^vim%-", "")
  name = name:gsub("^nvim%-", "")
  name = name:gsub("%.nvim$", "")
  name = name:gsub("%.vim$", "")
  return name
end

--- Group `scripts` into bundles, then attach commands and mappings.
---
--- @param scripts      table   list from collector.get_scripts()
--- @param commands     table   dict from collector.get_commands()
--- @param mappings_by_mode table  { mode = list_from_get_mappings() }
--- @return table  sorted list of bundle objects
function M.build_bundles(scripts, commands, mappings_by_mode)
  -- Map from bundle root → bundle object
  local root_to_bundle = {}
  -- Map from script sid → bundle object (for O(1) lookups)
  local sid_to_bundle = {}

  -- First pass: group scripts
  for _, script in ipairs(scripts) do
    local root = M.bundle_root_from_path(script.name)
    if not root_to_bundle[root] then
      root_to_bundle[root] = {
        name          = M.bundle_name_from_path(script.name),
        root          = root,
        scripts       = {},
        commands      = {},
        mappings      = {},
        abbreviations = {},
        functions     = {},
        highlights    = {},
      }
    end
    local bundle = root_to_bundle[root]
    table.insert(bundle.scripts, script)
    sid_to_bundle[script.sid] = bundle
  end

  -- Second pass: assign commands to their bundles via script_id
  for name, cmd in pairs(commands) do
    local bundle = sid_to_bundle[cmd.script_id]
    if bundle then
      table.insert(bundle.commands, {
        name       = name,
        definition = cmd.definition or "",
        nargs      = cmd.nargs or "0",
        bang       = cmd.bang or false,
        range      = cmd.range or "",
      })
    end
  end

  -- Third pass: assign mappings to their bundles via sid
  for mode, maps in pairs(mappings_by_mode) do
    for _, map in ipairs(maps) do
      local bundle = sid_to_bundle[map.sid]
      if bundle then
        table.insert(bundle.mappings, {
          mode = mode,
          lhs  = map.lhs,
          rhs  = map.rhs or "",
          desc = map.desc or "",
          sid  = map.sid,
        })
      end
    end
  end

  -- Collect into a sorted list
  local bundles = {}
  for _, bundle in pairs(root_to_bundle) do
    -- Sort commands / mappings within each bundle for stable output
    table.sort(bundle.commands, function(a, b) return a.name < b.name end)
    table.sort(bundle.mappings, function(a, b)
      if a.mode ~= b.mode then return a.mode < b.mode end
      return a.lhs < b.lhs
    end)
    table.insert(bundles, bundle)
  end

  table.sort(bundles, function(a, b) return a.name:lower() < b.name:lower() end)
  return bundles
end

return M
