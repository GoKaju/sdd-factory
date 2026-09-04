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
  /** the triage comment exists and has no open question */
  triageClean: boolean
  /** a Task comment exists and every step is ticked */
  taskComplete: boolean
  /** the latest review cycle aggregated to PASS and the PR is ready */
  reviewPassed: boolean
  /** minutes since the issue was last updated */
  idleMinutes: number
  /**
   * Verifiable cleanliness of the artifact waiting for approval in the current state:
   * spec → its Open questions section has no unchecked item and no TBD/TODO;
   * design → no "pending human confirmation" / NEEDS_HUMAN marker;
   * task → the Task comment exists with at least one step;
   * and, for all three, the last run of the producing phase reported no BLOCKER, FAIL or NEEDS_HUMAN.
   */
  artifactClean: boolean
}

export type Gate = 'Intake' | 'Spec' | 'Design' | 'Task' | 'Final'

export type Decision =
  | { phases: Phase[]; approve?: undefined; merge?: undefined; reason: string }
  | { phases?: undefined; approve: SddState; merge?: undefined; reason: string }
  | { phases?: undefined; approve?: undefined; merge: true; reason: string }

export interface RuleOptions {
  autoSpec: boolean
  staleImplementingMinutes: number
  /** Human approval gates this project lets the worker approve on its own (constitution → Verification). */
  autoApprove: ReadonlySet<Gate>
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
      if (issue.newCommentSinceTriage) return { phases: ['triage'], reason: 'author answered' }
      if (issue.triageClean && o.autoApprove.has('Intake')) return { approve: 'ready', reason: 'Intake auto-approved: no open questions' }
      return null
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
      return o.autoApprove.has('Spec') && issue.artifactClean ? { approve: 'spec-approved', reason: 'Spec auto-approved: no open question, clean completeness run' } : null
    case 'design':
      return o.autoApprove.has('Design') && issue.artifactClean ? { approve: 'design-approved', reason: 'Design auto-approved: nothing pending human confirmation, clean self-review' } : null
    case 'task':
      return o.autoApprove.has('Task') && issue.artifactClean ? { approve: 'task-approved', reason: 'Task auto-approved: steps present, clean run' } : null
    case 'final-review':
      // A Constitution amendment is never merged without a human, whatever the constitution says:
      // otherwise one delegated Final would let the rules rewrite themselves with nobody watching.
      if (t === 'Constitution') return null
      return o.autoApprove.has('Final') && issue.reviewPassed ? { merge: true, reason: 'Final auto-approved: every gate PASS' } : null
  }
}

/**
 * Parses `- **Auto-approved phase gates:** Intake, Task` (or the older `Auto-approved gates`) from the
 * constitution's Verification section. Only the five phase-gate names are recognised; the six Review
 * Gates (Spec Compliance, Design & Architecture, …) can never be delegated and are ignored here.
 */
export const autoApproveFromConstitution = (constitution: string): Set<Gate> => {
  const m = /Auto-approved (?:phase )?gates:\*\*\s*([^\n]*)/i.exec(constitution)
  const out = new Set<Gate>()
  if (!m || !m[1]) return out
  for (const raw of m[1].split(/[,·;]/)) {
    const g = raw.trim().replace(/[`*]/g, '').replace(/\s*[—(-].*$/, '')
    // Exact match only: "Spec Compliance" or "Design & Architecture" are Review Gates, not phase gates.
    if (g === 'Intake' || g === 'Spec' || g === 'Design' || g === 'Task' || g === 'Final') out.add(g)
  }
  return out
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

/** True when a phase summary reports nothing a human should look at first. */
export const summaryClean = (summary: string | null | undefined): boolean =>
  !summary || !/NEEDS_HUMAN|BLOCKER|\bFAIL\b|pregunta(s)? abierta|open question|sin resolver|unresolved/i.test(summary)

/** The spec's "Open questions" section has no unchecked item and no placeholder. */
export const specClean = (spec: string): boolean => {
  const start = spec.search(/^## Open questions[^\n]*\n/m)
  if (start < 0) return true
  const rest = spec.slice(start).replace(/^[^\n]*\n/, '')
  const end = rest.search(/^## /m)
  const section = end < 0 ? rest : rest.slice(0, end)
  return !/^- \[ \]/m.test(section) && !/\b(TBD|TODO|por definir)\b|\?\?\?/i.test(section)
}

/** The design carries no decision still waiting for a human. */
export const designClean = (design: string): boolean =>
  !/NEEDS_HUMAN|pendiente de confirmaci[oó]n|pending human|\b(TBD|TODO)\b/i.test(design)
