#!/usr/bin/env bash
# One git worktree per issue, inside the repository under .sdd/worktrees/issue-<N> (git-ignored), so the phases
# of /sdd work on the issue's branch while the human's checkout stays untouched and two issues can run at once.
#
#   sdd worktree ensure <issue> [<branch>]  → creates the worktree if missing (on the PR branch when the issue has a PR,
#                                             else on <branch> created from origin/<default>) and prints its path
#   sdd worktree path <issue>               → prints the path (exit 1 when there is none)
#   sdd worktree list                       → one line per issue worktree: "<issue> <branch> <path>"
#   sdd worktree clean <issue>              → removes the worktree (never the branch); safe when it does not exist
. "$(dirname "$0")/lib.sh"
S="$(dirname "$0")"

root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "run inside the repository"
# from inside an issue worktree, resolve the main checkout so paths stay stable
common="$(git -C "$root" rev-parse --git-common-dir)"; case "$common" in /*) ;; *) common="$root/$common";; esac
main="$(cd "$(dirname "$common")" && pwd -P)"
dir="$main/.sdd/worktrees"
default_branch() { git -C "$main" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true; }

cmd="${1:-}"; shift || true
case "$cmd" in
  list) git -C "$main" worktree list --porcelain | awk '/^worktree /{p=$2} /^branch /{b=$2; sub("refs/heads/","",b); if (p ~ /\/.sdd\/worktrees\/issue-[0-9]+$/) { n=p; sub(/.*issue-/,"",n); print n, b, p }}' ;;
  path) need_issue "${1:-}"; p="$dir/issue-$1"; [ -d "$p/.git" ] || [ -f "$p/.git" ] || exit 1; printf '%s\n' "$p" ;;
  ensure)
    need_issue "${1:-}"; issue="$1"; want="${2:-}"; p="$dir/issue-$issue"
    mkdir -p "$dir"
    grep -qxF '.sdd/worktrees/' "$main/.gitignore" 2>/dev/null || printf '.sdd/worktrees/\n' >> "$main/.gitignore"
    git -C "$main" fetch -q origin 2>/dev/null || true
    branch="$("$S/pr.sh" branch "$issue" 2>/dev/null || true)"; branch="${branch:-$want}"
    base="$(default_branch)"; base="${base:-main}"
    if [ -f "$p/.git" ]; then
      cur="$(git -C "$p" rev-parse --abbrev-ref HEAD)"
      if [ -n "$branch" ] && [ "$cur" != "$branch" ]; then
        git -C "$p" fetch -q origin "$branch" 2>/dev/null || true
        git -C "$p" checkout -q "$branch" 2>/dev/null || git -C "$p" checkout -q -b "$branch" "origin/$branch" 2>/dev/null || git -C "$p" checkout -q -b "$branch" "origin/$base"
      fi
    else
      [ -n "$branch" ] || die "issue #$issue has no PR: pass the branch to create, e.g. sdd worktree ensure $issue feat/$issue-slug"
      if git -C "$main" show-ref -q --verify "refs/remotes/origin/$branch"; then
        git -C "$main" worktree add -q "$p" "$branch" 2>/dev/null || git -C "$main" worktree add -q --track -b "$branch" "$p" "origin/$branch"
      elif git -C "$main" show-ref -q --verify "refs/heads/$branch"; then git -C "$main" worktree add -q "$p" "$branch"
      else git -C "$main" worktree add -q -b "$branch" "$p" "origin/$base"; fi
    fi
    [ -n "$branch" ] && git -C "$p" pull -q --ff-only origin "$branch" 2>/dev/null || true
    printf '%s\n' "$p"
    ;;
  clean)
    need_issue "${1:-}"; p="$dir/issue-$1"
    if [ -d "$p" ]; then git -C "$main" worktree remove --force "$p" 2>/dev/null || rm -rf "$p"; git -C "$main" worktree prune; printf 'removed %s\n' "$p"; else printf 'no worktree for #%s\n' "$1"; fi
    ;;
  *) sed -n '2,10p' "$0"; exit 1 ;;
esac
