import type { Phase, Tier } from './types.ts'

export const skillFor = (phase: Phase): string => `sdd-factory:sdd-${phase}`

/** Wall-clock budget per phase, in minutes, for a `standard`/`strong` model. */
export const timeoutMinutes: Record<Phase, number> = {
  triage: 15, spec: 30, design: 30, task: 15, implement: 90, review: 60,
}

/** Frontier models think longer per turn; the same work needs more wall-clock, not more turns. */
const BUDGET_FACTOR: Record<Tier, number> = { light: 1, standard: 1, strong: 1, frontier: 1.5 }

/** Wall-clock budget per phase and tier, in minutes. */
export const budgetMinutes = (phase: Phase, tier: Tier = 'standard'): number => Math.round(timeoutMinutes[phase] * BUDGET_FACTOR[tier])

/** Tools a headless phase may use; hooks of the plugin still apply. */
export const allowedToolsFor = (phase: Phase): string[] =>
  phase === 'triage'
    ? ['Bash', 'Read', 'Glob', 'Grep']
    : ['Bash', 'Read', 'Write', 'Edit', 'MultiEdit', 'Glob', 'Grep', 'Agent']

/** Triage never touches the repository, so it needs no worktree and no slot of the parallel budget. */
export const needsWorktree = (phase: Phase): boolean => phase !== 'triage'
