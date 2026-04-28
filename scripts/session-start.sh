#!/usr/bin/env bash
# session-start.sh — Print a status summary at the start of every agent/dev session.
#
# Goals:
#   * Surface the bits an agent (or a human) needs to know in the first 5 seconds.
#   * Exit 0 always; this is a status print, not a quality gate.
#   * No external deps beyond git, awk, and a POSIX shell.
#
# Usage:
#   scripts/session-start.sh
#
# Optional env vars:
#   HEADLIGHTS_GH_OFFLINE=1   skip the `gh issue list` call

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

bold()  { printf '\033[1m%s\033[0m' "$1"; }
dim()   { printf '\033[2m%s\033[0m' "$1"; }
green() { printf '\033[32m%s\033[0m' "$1"; }
yellow(){ printf '\033[33m%s\033[0m' "$1"; }
red()   { printf '\033[31m%s\033[0m' "$1"; }
blue()  { printf '\033[34m%s\033[0m' "$1"; }

hr() { printf '%s\n' "──────────────────────────────────────────────────────"; }

echo
hr
printf '  %s  %s\n' "$(bold "headlights.nvim")" "$(dim "session start")"
hr

# -- Git ----------------------------------------------------------------------
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')
sha=$(git rev-parse --short HEAD 2>/dev/null || echo '?')
upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo '(no upstream)')
ahead_behind=$(git rev-list --left-right --count "$upstream"...HEAD 2>/dev/null | awk '{printf "behind %s ahead %s", $1, $2}')
dirty="clean"
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  dirty="$(yellow 'dirty')"
fi

printf '  %-12s %s %s\n' "$(bold branch:)"   "$branch"      "$(dim "($sha)")"
printf '  %-12s %s %s\n' "$(bold upstream:)" "$upstream"    "$(dim "$ahead_behind")"
printf '  %-12s %s\n'    "$(bold worktree:)" "$dirty"

# -- Project meta -------------------------------------------------------------
version="(unset)"
[ -f VERSION ] && version="$(cat VERSION | tr -d '[:space:]')"
printf '  %-12s %s\n' "$(bold version:)"  "$version"

# -- Recent commits -----------------------------------------------------------
echo
echo "$(bold 'recent commits')"
git log --oneline -5 2>/dev/null | sed 's/^/    /'

# -- Latest changelog entry ---------------------------------------------------
if [ -f CHANGELOG.md ]; then
  echo
  echo "$(bold 'latest changelog entry')"
  awk '
    /^## / { if (seen) exit; seen=1; print; next }
    seen   { print }
  ' CHANGELOG.md | head -25 | sed 's/^/    /'
fi

# -- Tests / lint quick state -------------------------------------------------
echo
echo "$(bold 'quality gates available')"
printf '    %-22s %s\n' "make smoke"   "single end-to-end command"
printf '    %-22s %s\n' "make test"    "full mini.test suite"
printf '    %-22s %s\n' "make lint"    "luacheck (if installed)"
printf '    %-22s %s\n' "scripts/session-end.sh" "run all gates + dump session summary"

# -- Open issues --------------------------------------------------------------
if [ -z "${HEADLIGHTS_GH_OFFLINE:-}" ] && command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    echo
    echo "$(bold 'open issues (top 8)')"
    gh issue list --state open --limit 8 --json number,title,labels \
      --template '{{range .}}    #{{.number}}  {{.title}}{{"\n"}}{{end}}' 2>/dev/null \
      || echo "    (gh issue list failed — skipping)"
  fi
fi

# -- Reminders ----------------------------------------------------------------
echo
echo "$(bold 'session reminders')"
cat <<'EOF'
    * Keep CHANGELOG.md updated as you go (under [Unreleased]).
    * Don't push to main or legacy directly; use the branch in AGENTS.md.
    * Run scripts/session-end.sh before reporting completion.
EOF

hr
echo
