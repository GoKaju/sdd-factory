export type IssueType = 'Feature' | 'Change' | 'Bug' | 'Task' | 'Constitution'
export type SddState =
  | 'triage' | 'ready' | 'spec' | 'spec-approved' | 'design' | 'design-approved'
  | 'task' | 'task-approved' | 'implementing' | 'in-review' | 'rework' | 'final-review'

export type Phase = 'triage' | 'spec' | 'design' | 'task' | 'implement' | 'review'

export interface IssueSnapshot {
  number: number
  type: IssueType | null
  state: SddState | null
  updatedAt: string
  /** a human commented after the triage comment was last updated */
  newCommentSinceTriage: boolean
  /** a Task comment exists and every step is ticked */
  taskComplete: boolean
  /** minutes since the issue was last updated */
  idleMinutes: number
}

export interface Decision {
  phases: Phase[]
  reason: string
}

export interface RuleOptions {
  autoSpec: boolean
  staleImplementingMinutes: number
}

/**
 * The state machine of the factory, seen from outside: given what GitHub shows, which phases
 * should run now. Pure and total. `*-approved` and `ready` are set only by humans; the worker
 * never sets them and never runs anything on states that wait for a human (spec, design, task,
 * final-review).
 */
export const decide = (issue: IssueSnapshot, o: RuleOptions): Decision | null => {
  const t = issue.type
  switch (issue.state) {
    case null:
      return { phases: ['triage'], reason: 'new issue without SDD state' }
    case 'triage':
      return issue.newCommentSinceTriage ? { phases: ['triage'], reason: 'author answered' } : null
    case 'ready':
      if (t === 'Feature' || t === 'Change') {
        return o.autoSpec ? { phases: ['spec'], reason: 'ready, autoSpec on' } : null
      }
      return { phases: ['task'], reason: `ready, ${t ?? 'untyped'} skips spec and design` }
    case 'spec-approved':
      return { phases: ['design'], reason: 'spec approved' }
    case 'design-approved':
      return issue.taskComplete
        ? { phases: ['review'], reason: 'document-only amendment: task already complete' }
        : { phases: ['task'], reason: 'design approved' }
    case 'task-approved':
      return { phases: ['implement', 'review'], reason: 'task approved' }
    case 'rework':
      return { phases: ['implement', 'review'], reason: 'rework requested' }
    case 'implementing':
      return issue.idleMinutes >= o.staleImplementingMinutes
        ? { phases: ['implement', 'review'], reason: `implementing idle for ${issue.idleMinutes} min: resume` }
        : null
    case 'in-review':
      return { phases: ['review'], reason: 'implementation finished, review pending' }
    case 'spec':
    case 'design':
    case 'task':
    case 'final-review':
      return null
  }
}

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
