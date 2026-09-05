import type { Phase } from './types.ts'

export const skillFor = (phase: Phase): string => `sdd-factory:sdd-${phase}`

/** Wall-clock budget per phase, in minutes. */
export const timeoutMinutes: Record<Phase, number> = {
  triage: 15, spec: 30, design: 30, task: 15, implement: 90, review: 60,
}

/** Tools a headless phase may use; hooks of the plugin still apply. */
export const allowedToolsFor = (phase: Phase): string[] =>
  phase === 'triage'
    ? ['Bash', 'Read', 'Glob', 'Grep']
    : ['Bash', 'Read', 'Write', 'Edit', 'MultiEdit', 'Glob', 'Grep', 'Agent']

/** Triage never touches the repository, so it needs no worktree and no slot of the parallel budget. */
export const needsWorktree = (phase: Phase): boolean => phase !== 'triage'
