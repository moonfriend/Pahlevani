#!/usr/bin/env bash
# Worktree helper — one git worktree per parallel task (agent or human).
#
# Why: several agents can work on different branches at the same time without
# full clones (which drift and duplicate secrets) and without seeing each
# other's files. Every worktree shares the main checkout's single .git.
# Convention and rules: CLAUDE.md → "Workspace, worktrees & context boundaries".
#
# Usage (run from the main checkout or any worktree):
#   scripts/wt.sh new  <branch> [base]   create worktree (new branch from [base], default main)
#   scripts/wt.sh list                    list worktrees
#   scripts/wt.sh path <branch>           print a branch's worktree path
#   scripts/wt.sh done <branch>           remove a clean worktree (branch is kept)
#
# `new` also links the gitignored env/ credential files from the main checkout
# (never copies them) and runs `flutter pub get`, so the worktree can build and
# run immediately. Set WT_SKIP_PUB_GET=1 to skip pub get.
set -euo pipefail

die() { echo "wt: $*" >&2; exit 1; }

# The main checkout is the parent of the shared .git, wherever we run from.
MAIN="$(cd "$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")" && pwd)"
WT_ROOT="$(dirname "$MAIN")/$(basename "$MAIN")-worktrees"

slug() { echo "${1//\//-}"; }

path_for_branch() {
  git -C "$MAIN" worktree list --porcelain |
    awk -v ref="refs/heads/$1" '/^worktree /{p=substr($0,10)} $0=="branch " ref {print p}'
}

link_env() {
  local dest="$1" f
  for f in "$MAIN"/env/*; do
    [[ -f "$f" ]] || continue
    case "$(basename "$f")" in *.example|README.md) continue ;; esac
    ln -sfn "$f" "$dest/env/$(basename "$f")"
  done
}

cmd_new() {
  local branch="${1:-}" base="${2:-main}"
  [[ -n "$branch" ]] || die "usage: wt.sh new <branch> [base]"
  local dest="$WT_ROOT/$(slug "$branch")"
  [[ ! -e "$dest" ]] || die "$dest already exists"
  local existing; existing="$(path_for_branch "$branch")"
  [[ -z "$existing" ]] || die "branch '$branch' is already checked out at $existing"

  mkdir -p "$WT_ROOT"
  if git -C "$MAIN" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$MAIN" worktree add "$dest" "$branch"
  else
    git -C "$MAIN" worktree add -b "$branch" "$dest" "$base"
  fi
  link_env "$dest"
  if [[ "${WT_SKIP_PUB_GET:-0}" != 1 ]]; then
    (cd "$dest" && flutter pub get >/dev/null) || echo "wt: flutter pub get failed — run it manually" >&2
  fi
  echo "ready: $dest"
}

cmd_done() {
  local branch="${1:-}"
  [[ -n "$branch" ]] || die "usage: wt.sh done <branch>"
  local dest; dest="$(path_for_branch "$branch")"
  [[ -n "$dest" ]] || die "no worktree for branch '$branch'"
  [[ "$dest" != "$MAIN" ]] || die "refusing to remove the main checkout"
  [[ -z "$(git -C "$dest" status --porcelain)" ]] ||
    die "$dest has uncommitted changes — commit or stash first"
  git -C "$MAIN" worktree remove "$dest"
  rmdir "$WT_ROOT" 2>/dev/null || true
  echo "removed $dest (branch '$branch' kept)"
}

case "${1:-}" in
  new)  shift; cmd_new "$@" ;;
  done) shift; cmd_done "$@" ;;
  list) git -C "$MAIN" worktree list ;;
  path) shift; p="$(path_for_branch "${1:-}")"; [[ -n "$p" ]] || die "no worktree for '${1:-}'"; echo "$p" ;;
  *)    sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
