#!/usr/bin/env bash
# session-end.sh — Run quality gates, print an end-of-session summary,
# and prompt the operator for merge/cleanup.
#
# This is the canonical "before you say done" routine. AI agents and humans
# alike should run it as the final step of any session that touched the repo.
#
# Exit codes:
#   0  all gates passed
#   1  smoke test failed
#   2  full test suite failed
#   3  changelog hygiene failed (Unreleased section is empty when there are
#      staged or unstaged changes)
#
# Usage:
#   scripts/session-end.sh           # run everything
#   scripts/session-end.sh --quick   # smoke + summary only (skip full suite)
#   scripts/session-end.sh --skip-tests  # summary only, no test execution

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

bold()  { printf '\033[1m%s\033[0m' "$1"; }
dim()   { printf '\033[2m%s\033[0m' "$1"; }
green() { printf '\033[32m%s\033[0m' "$1"; }
yellow(){ printf '\033[33m%s\033[0m' "$1"; }
red()   { printf '\033[31m%s\033[0m' "$1"; }

hr() { printf '%s\n' "──────────────────────────────────────────────────────"; }

mode="full"
case "${1:-}" in
  --quick)       mode="quick" ;;
  --skip-tests)  mode="skip"  ;;
  ""|--full)     mode="full"  ;;
  *) echo "unknown flag: $1" >&2; exit 64 ;;
esac

echo
hr
printf '  %s  %s (%s)\n' "$(bold "headlights.nvim")" "$(dim "session end")" "$mode"
hr

# ---------------------------------------------------------------------------
# 1. Smoke test
# ---------------------------------------------------------------------------
smoke_status="skipped"
if [ "$mode" != "skip" ]; then
  echo
  echo "$(bold '[1/3]') running smoke test  $(dim '(make smoke)')"
  if make -s smoke; then
    smoke_status="$(green 'pass')"
  else
    smoke_status="$(red 'FAIL')"
    echo
    echo "$(red 'smoke test failed — fix before declaring session complete')"
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# 2. Full test suite
# ---------------------------------------------------------------------------
full_status="skipped"
if [ "$mode" = "full" ]; then
  echo
  echo "$(bold '[2/3]') running full test suite  $(dim '(make test)')"
  if make -s test; then
    full_status="$(green 'pass')"
  else
    full_status="$(red 'FAIL')"
    echo
    echo "$(red 'full test suite failed — fix before declaring session complete')"
    exit 2
  fi
fi

# ---------------------------------------------------------------------------
# 3. Changelog hygiene
# ---------------------------------------------------------------------------
echo
echo "$(bold '[3/3]') changelog hygiene"

if [ ! -f CHANGELOG.md ]; then
  echo "    $(yellow 'CHANGELOG.md missing')"
  changelog_status="$(yellow 'missing')"
else
  changelog_status="$(green 'ok')"
  has_changes=0
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    has_changes=1
  fi
  if [ "$has_changes" -eq 1 ]; then
    # If there are pending changes, the Unreleased section should not be empty.
    unrel=$(awk '
      /^## \[Unreleased\]/ { found=1; next }
      found && /^## /      { exit }
      found                { print }
    ' CHANGELOG.md | grep -v '^[[:space:]]*$' || true)
    if [ -z "$unrel" ]; then
      echo "    $(yellow 'pending git changes but [Unreleased] section is empty')"
      echo "    $(dim 'add a bullet under [Unreleased] in CHANGELOG.md')"
      changelog_status="$(yellow 'empty')"
    fi
  fi
  printf '    status: %s\n' "$changelog_status"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
hr
printf '  %s\n' "$(bold session summary)"
hr

branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')
sha=$(git rev-parse --short HEAD 2>/dev/null || echo '?')
version="(unset)"
[ -f VERSION ] && version="$(cat VERSION | tr -d '[:space:]')"

printf '  %-14s %s\n' "$(bold branch:)"     "$branch ($sha)"
printf '  %-14s %s\n' "$(bold version:)"    "$version"
printf '  %-14s %s\n' "$(bold smoke:)"      "$smoke_status"
printf '  %-14s %s\n' "$(bold full suite:)" "$full_status"
printf '  %-14s %s\n' "$(bold changelog:)"  "$changelog_status"

# Files changed since divergence with the trunk (origin/main, falling back
# to origin/master for older clones during the rename window).
echo
trunk="origin/main"
git rev-parse --verify "$trunk" >/dev/null 2>&1 || trunk="origin/master"
git rev-parse --verify "$trunk" >/dev/null 2>&1 || trunk="main"
git rev-parse --verify "$trunk" >/dev/null 2>&1 || trunk="master"
echo "$(bold 'files changed since') $trunk"
git diff --stat "$trunk"...HEAD 2>/dev/null | sed 's/^/    /' || \
  echo "    (diff against trunk unavailable)"

# Latest changelog entry
if [ -f CHANGELOG.md ]; then
  echo
  echo "$(bold 'latest changelog entry')"
  awk '
    /^## / { if (seen) exit; seen=1; print; next }
    seen   { print }
  ' CHANGELOG.md | head -40 | sed 's/^/    /'
fi

# Final prompt
echo
hr
echo "$(bold 'next steps for the operator')"
cat <<EOF
    1.  Review the diff:        git diff $trunk...HEAD
    2.  Push the branch:        git push -u origin $branch
    3.  Open / merge the PR via GitHub.
    4.  After merge, locally:   git checkout main && git pull && git branch -d $branch
EOF
hr
echo

exit 0
