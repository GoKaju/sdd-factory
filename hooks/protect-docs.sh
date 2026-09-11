#!/usr/bin/env bash
# Claude Code PreToolUse (Write|Edit): protects the constitution and, while an issue is being implemented,
# the approved spec.md / design.md files.
#
# Flags (files under ~/.sdd/<owner>-<repo>/, written by /sdd via `sdd flag`):
#   allow-constitution   present while the implement phase runs a Constitution-type issue
#   lock-docs            present from the implement phase until the review PASSes
# Paths are resolved against the checkout that holds the file, so the rules hold inside issue worktrees too.
set -u
. "$(dirname "$0")/lib.sh"
read_stdin
path="$(json_field file_path)"
[ -z "$path" ] && exit 0

case "$path" in /*) ;; *) path="$(call_cwd)/$path";; esac
root="$(repo_top_of "$path")"
rel="${path#"$root"/}"

case "$rel" in
  docs/constitution.md)
    has_flag allow-constitution || block "docs/constitution.md changes only through a Constitution-type issue (/sdd sets the flag while implementing one). Rule W3."
    ;;
  docs/*/*/spec.md|docs/*/*/design.md|docs/adrs/*.md)
    has_flag lock-docs && block "$rel is approved and the issue is in implementation/review. Stop and reclassify the issue as Change instead of editing spec, design or ADRs in passing. Rule W3."
    ;;
esac
exit 0
