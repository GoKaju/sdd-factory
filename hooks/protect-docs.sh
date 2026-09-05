#!/usr/bin/env bash
# PreToolUse (Write|Edit): protects the constitution and, while an issue is being implemented,
# the approved spec.md / design.md files.
#
# Flags (files under ~/.sdd/<owner>-<repo>/, written by the sdd-* skills via scripts/sdd-flag.sh):
#   allow-constitution   present while /sdd-implement runs a Constitution-type issue
#   lock-docs            present from /sdd-implement until /sdd-review PASSes; set by the skills
set -u
. "$(dirname "$0")/lib.sh"
read_stdin
path="$(json_field file_path)"
[ -z "$path" ] && exit 0

root="$(project_dir)"
rel="${path#"$root"/}"

case "$rel" in
  docs/constitution.md)
    has_flag allow-constitution || block "docs/constitution.md changes only through a Constitution-type issue (/sdd-implement sets the flag). Rule W4."
    ;;
  docs/*/*/spec.md|docs/*/*/design.md|docs/adrs/*.md)
    has_flag lock-docs && block "$rel is approved and the issue is in implementation/review. Stop and reclassify the issue as Change instead of editing spec, design or ADRs in passing. Rule W4."
    ;;
esac
exit 0
