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
-- Each pattern captures (root_path, plugin_folder_name).
local BUILTIN_PATTERNS = {}
for _, dir in ipairs(PLUGIN_MANAGER_DIRS) do
  -- e.g. /home/user/.vim/plugged/vim-fugitive/...  →  root = .../plugged/vim-fugitive
  table.insert(BUILTIN_PATTERNS, "^(.*/" .. dir .. "/([^/]+))/")
end
-- Also handle pack/<manager>/start|opt/<plugin>
table.insert(BUILTIN_PATTERNS, "^(.*/pack/[^/]+/[^/]+/([^/]+))/")

-- Strip common plugin-name decorations to get a clean display name.
function M._clean_name(raw)
  local name = raw
  name = name:gsub("^vim%-", "")
  name = name:gsub("^nvim%-", "")
  name = name:gsub("%.nvim$", "")
  name = name:gsub("%.vim$", "")
  return name
end

local function effective_patterns(extra)
  if not extra or #extra == 0 then return BUILTIN_PATTERNS end
  -- User patterns take precedence so non-standard layouts (Nix, custom rtp)
  -- match before the built-ins fall back to a generic two-dirs-up heuristic.
  local merged = {}
  for _, p in ipairs(extra) do table.insert(merged, p) end
  for _, p in ipairs(BUILTIN_PATTERNS) do table.insert(merged, p) end
  return merged
end

--- Return (root, raw_folder_name) for `path`, or (root, nil) for the
--- generic two-dirs-up fallback.
--- @param path string
--- @param extra_patterns? table  list of additional Lua patterns
--- @return string root
--- @return string|nil raw_name
function M.bundle_root_from_path(path, extra_patterns)
  for _, pat in ipairs(effective_patterns(extra_patterns)) do
    local root, folder = path:match(pat)
    if root then return root, folder end
  end
  -- Fallback: two directories up from the file
  return (path:match("^(.+/[^/]+/[^/]+)/[^/]+$")
      or path:match("^(.+)/[^/]+$")
      or path), nil
end

--- Derive a human-readable bundle name from `path`.
--- @param path string
--- @param extra_patterns? table
function M.bundle_name_from_path(path, extra_patterns)
  for _, pat in ipairs(effective_patterns(extra_patterns)) do
    local _, folder = path:match(pat)
    if folder then
      return M._clean_name(folder)
    end
  end
  -- Fallback: use the filename without extension
  local filename = path:match("([^/]+)%.[^.]+$") or path:match("([^/]+)$")
  return filename or path
end

-- ---------------------------------------------------------------------------
-- Source-path attribution helper
--
-- Match a `Last set from /path/...` source string against the bundle root
-- map. Returns the matching bundle (longest-prefix wins) or nil.
-- ---------------------------------------------------------------------------
local function bundle_for_source_path(source, root_to_bundle)
  if not source or source == "" then return nil end
  -- Expand `~` if present (some Vim builds quote with $HOME etc.)
  source = source:gsub("^~", os.getenv("HOME") or "~")

  local best, best_len = nil, 0
  for root, bundle in pairs(root_to_bundle) do
    if root and #root > 0 and source:sub(1, #root) == root and #root > best_len then
      best, best_len = bundle, #root
    end
  end
  return best
end

-- ---------------------------------------------------------------------------
-- Autocmd / sign augroup attribution helper
--
-- Given a string (augroup name or sign name) and the list of bundles built
-- so far, find the bundle whose name appears as a case-insensitive
-- substring of the input. Longest match wins so "Telescope" beats "tele".
-- ---------------------------------------------------------------------------
local function bundle_for_name_match(needle, bundles_by_name)
  if not needle or needle == "" then return nil end
  local lower = needle:lower()
  local best, best_len = nil, 0
  for name, bundle in pairs(bundles_by_name) do
    if #name >= 3 and lower:find(name:lower(), 1, true) and #name > best_len then
      best, best_len = bundle, #name
    end
  end
  return best
end

--- Group `scripts` into bundles, then attach commands and mappings.
---
--- @param scripts          table   list from collector.get_scripts()
--- @param commands         table   dict from collector.get_commands()
--- @param mappings_by_mode table   { mode = list_from_get_mappings() }
--- @param extra_patterns?  table   extra Lua patterns (see config.extra_plugin_dirs)
--- @param extras?          table   optional extra resource lists:
---                                 { abbreviations, highlights, autocmds, signs }
--- @return table  sorted list of bundle objects
function M.build_bundles(scripts, commands, mappings_by_mode, extra_patterns, extras)
  extras = extras or {}
  local patterns = effective_patterns(extra_patterns)

  -- Map from bundle root → bundle object
  local root_to_bundle = {}
  -- Map from script sid → bundle object (for O(1) lookups)
  local sid_to_bundle = {}

  -- First pass: group scripts
  for _, script in ipairs(scripts) do
    local root = M.bundle_root_from_path(script.name, patterns)
    if not root_to_bundle[root] then
      root_to_bundle[root] = {
        name          = M.bundle_name_from_path(script.name, patterns),
        root          = root,
        scripts       = {},
        commands      = {},
        mappings      = {},
        abbreviations = {},
        functions     = {},
        highlights    = {},
        autocmds      = {},
        signs         = {},
      }
    end
    local bundle = root_to_bundle[root]
    table.insert(bundle.scripts, script)
    sid_to_bundle[script.sid] = bundle

    -- Function attribution (#25, partial) — Neovim's getscriptinfo()
    -- returns a per-script `functions` field listing global function names
    -- defined by that script. We honour it when present.
    if type(script.functions) == "table" then
      for _, fname in ipairs(script.functions) do
        table.insert(bundle.functions, fname)
      end
    end
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

  -- Abbreviation attribution (#25) — match parsed `Last set from` source.
  for _, ab in ipairs(extras.abbreviations or {}) do
    local bundle = bundle_for_source_path(ab.source, root_to_bundle)
    if bundle then
      table.insert(bundle.abbreviations, {
        mode = ab.mode, lhs = ab.lhs, rhs = ab.rhs, source = ab.source,
      })
    end
  end

  -- Highlight attribution (#25) — match parsed `Last set from` source.
  for _, hl in ipairs(extras.highlights or {}) do
    local bundle = bundle_for_source_path(hl.source, root_to_bundle)
    if bundle then
      table.insert(bundle.highlights, hl.name)
    end
  end

  -- Build a name → bundle map for autocmd / sign attribution.
  local bundles_by_name = {}
  for _, bundle in pairs(root_to_bundle) do
    bundles_by_name[bundle.name] = bundle
  end

  -- Autocmd attribution (#26) — try augroup name first; fall back to a
  -- substring match against bundle names. Unattributed entries are
  -- returned in `unattributed_autocmds` for the caller to surface.
  local unattributed_autocmds = {}
  for _, ac in ipairs(extras.autocmds or {}) do
    local key = ac.group_name or ac.group or ""
    local bundle = bundle_for_name_match(key, bundles_by_name)
    if bundle then
      table.insert(bundle.autocmds, ac)
    else
      table.insert(unattributed_autocmds, ac)
    end
  end

  -- Sign attribution — match sign name (and any "texthl"/"linehl" group
  -- name) against bundle names. Unattributed signs go in their own list.
  local unattributed_signs = {}
  for _, sg in ipairs(extras.signs or {}) do
    local needle = (sg.name or "") .. " " .. (sg.texthl or "") .. " " .. (sg.linehl or "")
    local bundle = bundle_for_name_match(needle, bundles_by_name)
    if bundle then
      table.insert(bundle.signs, sg)
    else
      table.insert(unattributed_signs, sg)
    end
  end

  -- Collect into a sorted list
  local bundles = {}
  for _, bundle in pairs(root_to_bundle) do
    -- Sort everything within each bundle for stable output
    table.sort(bundle.commands, function(a, b) return a.name < b.name end)
    table.sort(bundle.mappings, function(a, b)
      if a.mode ~= b.mode then return a.mode < b.mode end
      return a.lhs < b.lhs
    end)
    table.sort(bundle.functions)
    table.sort(bundle.abbreviations, function(a, b) return a.lhs < b.lhs end)
    table.sort(bundle.highlights)
    table.sort(bundle.autocmds, function(a, b)
      return (a.event or "") < (b.event or "")
    end)
    table.sort(bundle.signs, function(a, b)
      return (a.name or "") < (b.name or "")
    end)
    table.insert(bundles, bundle)
  end

  table.sort(bundles, function(a, b) return a.name:lower() < b.name:lower() end)

  -- Second return value carries items that couldn't be attributed to any
  -- known plugin, so callers can surface them under a synthetic bundle.
  -- Existing callers that capture only `bundles` are unaffected.
  return bundles, {
    autocmds = unattributed_autocmds,
    signs    = unattributed_signs,
  }
end

return M
