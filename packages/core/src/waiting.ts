import type { IssueSnapshot } from './types.ts'

/** Which human decision an issue in this state waits for (null when the orchestrator or nobody acts). */
export const waitingFor = (i: Pick<IssueSnapshot, 'state' | 'triageClean' | 'artifactClean' | 'reviewPassed'>, autoApprove: ReadonlySet<string>): string | null => {
  switch (i.state) {
    case 'triage': return i.triageClean ? (autoApprove.has('Intake') ? null : 'set sdd:ready (Gate 0)') : 'answer the triage questions'
    case 'spec': return autoApprove.has('Spec') && i.artifactClean ? null : 'approve the spec (Gate 1)'
    case 'design': return autoApprove.has('Design') && i.artifactClean ? null : 'approve the design (Gate 2)'
    case 'task': return autoApprove.has('Task') && i.artifactClean ? null : 'approve the Task (Gate 3)'
    case 'final-review': return autoApprove.has('Final') && i.reviewPassed ? null : 'review and merge the PR (Gate 4)'
    default: return null
  }
}
