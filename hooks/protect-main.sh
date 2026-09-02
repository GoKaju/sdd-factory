#!/usr/bin/env bash
# PreToolUse (Bash): never push to main/master, never force-push, never rewrite published history.
set -u
. "$(dirname "$0")/lib.sh"
read_stdin
cmd="$(json_field command)"
[ -z "$cmd" ] && exit 0

# Normalise whitespace so "git  push" and multi-line chains are matched.
flat="$(printf '%s' "$cmd" | tr '\n' ' ' | tr -s ' ')"

if printf '%s' "$flat" | grep -Eq '(^|[;&| ])git push'; then
  printf '%s' "$flat" | grep -Eq 'git push[^;&|]*( -f| --force)' && block "force push is denied. Rule W2."
  printf '%s' "$flat" | grep -Eq 'git push[^;&|]*(origin|upstream)?[[:space:]]+(main|master)([[:space:]]|$)' && block "push to main is denied; open a PR. Rule W1."
  # `git push` with no refspec while on main
  if printf '%s' "$flat" | grep -Eq 'git push([[:space:]]+(-u|--set-upstream|origin|upstream))*([;&|]|$)'; then
    branch="$(git -C "$(project_dir)" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    case "$branch" in main|master) block "you are on $branch; push to main is denied. Rule W1." ;; esac
  fi
fi

printf '%s' "$flat" | grep -Eq '(^|[;&| ])git (rebase|reset --hard|commit --amend|push --force-with-lease)' && \
  block "rewriting history is denied (rebase, reset --hard, amend). Fix with a new commit. Rule W2."

exit 0
