#!/usr/bin/env bash
# Claude Code PreToolUse (Bash): never push to main/master, never force-push, never rewrite published history.
# Works from the main checkout and from issue worktrees (`cd <path> && git push`, `git -C <path> push`).
set -u
. "$(dirname "$0")/lib.sh"
read_stdin
cmd="$(json_field command)"
[ -z "$cmd" ] && exit 0

# Normalise whitespace so "git  push" and multi-line chains are matched.
flat="$(printf '%s' "$cmd" | tr '\n' ' ' | tr -s ' ')"
# `git -C <path> push` reads as `git push` for the patterns; the path is recovered below for the branch check
cdir="$(printf '%s' "$flat" | grep -oE "git +-C +['\"]?[^ '\";&|]+" | tail -1 | sed -E "s/.*-C +['\"]?//")"
flat="$(printf '%s' "$flat" | sed -E "s/git +-C +['\"]?[^ '\";&|]+['\"]? +/git /g")"

if printf '%s' "$flat" | grep -Eq '(^|[;&| ])git push'; then
  printf '%s' "$flat" | grep -Eq 'git push[^;&|]*( -f| --force)' && block "force push is denied. Rule W2."
  printf '%s' "$flat" | grep -Eq 'git push[^;&|]*(origin|upstream)?[[:space:]]+(main|master)([[:space:]]|$)' && block "push to main is denied; open a PR. Rule W1."
  # `git push` with no refspec while on the default branch: strip every option (-q, -u, --tags, -o …) and see whether a ref remains
  rest="$(printf '%s' "$flat" | sed -E 's/.*git push//; s/[;&|].*$//' | tr ' ' '\n' | grep -vE '^(-.*|origin|upstream)?$' | head -1)"
  if [ -z "$rest" ]; then
    dir="$(printf '%s' "$flat" | grep -oE "(^|[;&|] *)cd +['\"]?[^ '\";&|]+" | tail -1 | sed -E "s/.*cd +['\"]?//")"
    [ -z "$dir" ] && dir="$cdir"
    case "$dir" in "") dir="$(call_cwd)";; /*) ;; *) dir="$(call_cwd)/$dir";; esac
    branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    case "$branch" in main|master) block "you are on $branch; push to main is denied. Rule W1." ;; esac
  fi
fi

printf '%s' "$flat" | grep -Eq '(^|[;&| ])git (rebase|reset --hard|commit --amend|push --force-with-lease)' && \
  block "rewriting history is denied (rebase, reset --hard, amend). Fix with a new commit. Rule W2."

exit 0
