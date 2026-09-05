export type IssueType = 'Feature' | 'Change' | 'Bug' | 'Task' | 'Constitution'
export type SddState =
  | 'triage' | 'ready' | 'spec' | 'spec-approved' | 'design' | 'design-approved'
  | 'task' | 'task-approved' | 'implementing' | 'in-review' | 'rework' | 'final-review'

export type Phase = 'triage' | 'spec' | 'design' | 'task' | 'implement' | 'review'
export type Gate = 'Intake' | 'Spec' | 'Design' | 'Task' | 'Final'
export type Size = 'S' | 'M' | 'L'
export type Tier = 'light' | 'standard' | 'strong' | 'frontier'
export type Lang = 'es' | 'en'

export const PHASES: readonly Phase[] = ['triage', 'spec', 'design', 'task', 'implement', 'review']
export const GATES: readonly Gate[] = ['Intake', 'Spec', 'Design', 'Task', 'Final']
export const TIERS: readonly Tier[] = ['light', 'standard', 'strong', 'frontier']

export const isTier = (v: unknown): v is Tier => v === 'light' || v === 'standard' || v === 'strong' || v === 'frontier'
export const isGate = (v: unknown): v is Gate => typeof v === 'string' && (GATES as readonly string[]).includes(v)

/** What an orchestrator needs to know about an open issue; everything here is read from GitHub. */
export interface IssueSnapshot {
  title: string
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
  /** triage size (S/M/L) from the triage comment, when known */
  size: Size | null
  /** review cycles already published on the PR (0 without PR) */
  reviewCycles: number
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
