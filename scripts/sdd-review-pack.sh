#!/usr/bin/env bash
# Builds the shared review pack for an issue's PR, so the Review Gate agents read one file instead of
# each exploring the repository: constitution, issue + comments (triage, Task), affected spec/design
# (approved version on the base branch and PR version), the full PR diff, touched files and test stats.
#
#   sdd-review-pack.sh build <issue> [cycle]   → prints the pack path (~/.sdd/<owner>-<repo>/review-pack-<issue>.md)
#   sdd-review-pack.sh path  <issue>           → prints the path without building
. "$(dirname "$0")/lib.sh"
S="$(dirname "$0")"

cmd="${1:-}"; need_issue "${2:-}"; issue="$2"; cycle="${3:-0}"
r="$(repo)"; dir="$HOME/.sdd/$(printf '%s' "$r" | tr '/' '-')"; mkdir -p "$dir"
out="$dir/review-pack-$issue.md"
[ "$cmd" = "path" ] && { printf '%s\n' "$out"; exit 0; }
[ "$cmd" = "build" ] || die "usage: sdd-review-pack.sh build|path <issue> [cycle]"

pr="$("$S/sdd-pr.sh" find "$issue")"; [ -n "$pr" ] || die "issue #$issue has no PR"
read -r head base < <(gh pr view "$pr" --json headRefOid,baseRefName -q '"\(.headRefOid) \(.baseRefName)"')
git fetch -q origin "$base" 2>/dev/null || true
files="$(gh pr diff "$pr" --name-only)"
section() { printf '\n\n## %s\n\n' "$1"; }
fence() { printf '```%s\n' "${1:-}"; cat; printf '\n```\n'; }

{
  printf '# Review pack · issue #%s · PR #%s · cycle %s\n\n' "$issue" "$pr" "$cycle"
  printf -- '- repo: %s\n- head: %s\n- base: %s\n- built: %s\n' "$r" "$head" "$base" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf -- '- This pack is the primary input of every Review Gate. Open repository files only for what it lacks (code surrounding a hunk, a file the diff references but does not contain).\n'

  section "Constitution (docs/constitution.md)"; cat docs/constitution.md
  section "Issue #$issue with comments (triage and Task included)"; gh issue view "$issue" --comments

  for f in $(printf '%s\n' "$files" | grep -E '^docs/.+/(spec|design)\.md$' || true); do
    section "$f — approved version on $base"
    git show "origin/$base:$f" 2>/dev/null || printf '(new in this PR)\n'
    section "$f — version in the PR"; cat "$f"
  done
  # spec/design of modules touched by code but not edited in the PR
  for d in $(printf '%s\n' "$files" | grep -E '^contexts/[^/]+/' | cut -d/ -f2 | sort -u); do
    for f in docs/*/"$d"/spec.md docs/*/"$d"/design.md docs/"$d"/*/spec.md docs/"$d"/*/design.md; do
      [ -f "$f" ] || continue
      printf '%s\n' "$files" | grep -qx "$f" && continue
      section "$f — current (unchanged in this PR)"; cat "$f"
    done
  done

  section "Files touched"; printf '%s\n' "$files" | fence
  section "Test changes vs $base (stat)"
  git diff --stat "origin/$base...$head" -- '*.test.*' '*.spec.*' '**/test/**' '**/tests/**' 2>/dev/null | fence || true
  removed="$(git diff "origin/$base...$head" -- '*.test.*' '*.spec.*' 2>/dev/null | grep -cE '^-\s*(it|test|describe)\(' || true)"
  printf '\nTest declarations removed in the PR (`it`/`test`/`describe` lines deleted): %s\n' "${removed:-0}"

  section "Full PR diff"; gh pr diff "$pr" | head -c 600000 | fence diff
} > "$out"
printf '%s\n' "$out"
