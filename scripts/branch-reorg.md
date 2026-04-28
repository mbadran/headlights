# Branch reorganisation — one-time operator steps

The v0.2.0 release reorganises the repository so that the modern Neovim Lua
rewrite is the default branch and the original Vim 7/8 + Python plugin lives
on a dedicated `legacy` branch.

These steps cannot be done via the GitHub MCP tools available to the agent,
so they need to be run **once, manually** by the operator after merging the
v0.2.0 PR. They are non-destructive (no force-push, no history rewrites).

## Current state on origin

| Branch       | SHA       | What it is                                         |
|--------------|-----------|----------------------------------------------------|
| `master`     | `2e80772` | Original Vim 7/8 + Python plugin (legacy code)     |
| `main`       | `2437963` | Modern Neovim Lua rewrite (currently has `legacy/` folder — this PR removes it) |
| `gh-pages`   | `e04868c` | Old GitHub Pages branch — leave alone              |

## Target state

| Branch    | What it is                                            |
|-----------|-------------------------------------------------------|
| `main`    | Default. Modern Lua codebase, no `legacy/` folder.    |
| `legacy`  | Frozen. Original Vim 7/8 + Python plugin.             |
| `gh-pages`| Untouched.                                            |

## Steps (in order)

### 1. Merge this PR into `main`

Standard merge via the GitHub UI (squash or merge — either is fine).
The PR removes the now-redundant `legacy/` folder from `main`.

### 2. Rename `master` → `legacy`

Either via the GitHub UI:

- Repository → Branches → next to `master` click the pencil icon → rename
  to `legacy` → confirm.

Or via the `gh` CLI:

```bash
gh api -X POST /repos/mbadran/headlights/branches/master/rename \
  -f new_name=legacy
```

### 3. Set `main` as the default branch

GitHub UI:

- Repository → Settings → General → Default branch → switch icon next to
  the current default → select `main` → "Update".

Or via the `gh` CLI:

```bash
gh api -X PATCH /repos/mbadran/headlights -f default_branch=main
```

### 4. (Optional) Delete the merged `claude/review-lua-migration-0eoF6` branch

GitHub UI offers a "Delete branch" button after the PR is merged.
Or:

```bash
git push origin --delete claude/review-lua-migration-0eoF6
```

### 5. Update local clones

On any local clone:

```bash
git fetch origin --prune
git branch -m master legacy
git branch -u origin/legacy legacy
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
git checkout main
```

## Verification

After the steps:

```bash
gh repo view mbadran/headlights --json defaultBranchRef,branches
```

Expected: `defaultBranchRef.name == "main"`; branches list contains
`legacy` and not `master`.

A fresh clone should land on `main` and not contain a `legacy/` directory.
