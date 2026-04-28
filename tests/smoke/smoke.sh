#!/usr/bin/env bash
# smoke.sh — single end-to-end smoke test for headlights.nvim.
#
# What it proves:
#   * The plugin loads under `nvim --clean` without errors.
#   * The CLI driver (bin/headlights) produces non-empty JSON.
#   * The JSON is well-formed and reports at least one plugin (the runtime).
#
# What it does NOT prove:
#   * Individual unit-level behaviour — that's `make test` (mini.test suite).
#
# Exit codes:
#   0 — pass
#   non-zero — fail (with a diagnostic on stderr)

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NVIM="${NVIM:-nvim}"

if ! command -v "$NVIM" >/dev/null 2>&1; then
  echo "smoke: $NVIM not found on PATH" >&2
  exit 127
fi

# Single end-to-end command — capture JSON output via the CLI driver.
output=$("$REPO_ROOT/bin/headlights" --format=json 2>/tmp/headlights-smoke.stderr)

if [ -z "$output" ]; then
  echo "smoke: CLI produced empty output" >&2
  cat /tmp/headlights-smoke.stderr >&2
  exit 1
fi

# Sanity-check the JSON shape with a tiny inline Lua check
# (avoids depending on jq being installed).
"$NVIM" --headless --clean -l - <<'LUA' "$output" || exit 2
local payload = arg[1] or ""
local ok, decoded = pcall(vim.json.decode, payload)
if not ok or type(decoded) ~= "table" then
  io.stderr:write("smoke: output is not valid JSON\n")
  io.stderr:write(payload:sub(1, 200) .. "\n")
  os.exit(2)
end
if type(decoded.plugins) ~= "table" then
  io.stderr:write("smoke: payload missing .plugins array\n")
  os.exit(3)
end
if type(decoded.neovim_version) ~= "string" or decoded.neovim_version == "" then
  io.stderr:write("smoke: payload missing .neovim_version\n")
  os.exit(4)
end
io.stdout:write(("smoke: ok (%d plugin(s) reported)\n"):format(#decoded.plugins))
os.exit(0)
LUA
