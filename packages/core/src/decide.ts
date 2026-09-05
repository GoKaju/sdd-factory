import type { Gate, IssueSnapshot, Phase, SddState } from './types.ts'

export type Decision =
  | { phases: Phase[]; approve?: undefined; merge?: undefined; reason: string }
  | { phases?: undefined; approve: SddState; merge?: undefined; reason: string }
  | { phases?: undefined; approve?: undefined; merge: true; reason: string }

export interface RuleOptions {
  autoSpec: boolean
  staleImplementingMinutes: number
  /** Human approval gates this project lets the orchestrator approve on its own (.sdd/config.json → approvals.auto). */
  autoApprove: ReadonlySet<Gate>
}

/**
 * The state machine of the factory, seen from outside: given what GitHub shows, which phases
 * should run now. Pure and total. `*-approved` and `ready` are set only by humans; the orchestrator
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
