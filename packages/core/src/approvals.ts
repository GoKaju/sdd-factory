import type { Gate, SddState } from './types.ts'

/** The `sdd:*-approved` / `sdd:ready` labels that only a human may set, and the gate each one closes. */
export const APPROVAL_STATES: Record<Gate, SddState> = {
  Intake: 'ready', Spec: 'spec-approved', Design: 'design-approved', Task: 'task-approved', Final: 'final-review',
}

export const isApprovalState = (state: string): boolean => (Object.values(APPROVAL_STATES) as string[]).includes(state)

export type Permission = 'admin' | 'maintain' | 'write' | 'triage' | 'read' | 'none'
const CAN_APPROVE: readonly Permission[] = ['admin', 'maintain', 'write']

export interface LabelEvent {
  label: string
  /** login of the actor; a GitHub App shows as `<slug>[bot]` */
  actor: string
  actorIsBot: boolean
  permission: Permission
}

/**
 * Does a label event count as a human approval? Only when the label is an approval state, the
 * actor is not an app or bot, and the actor has write access or more. With the factory acting under
 * its own GitHub App identity this becomes enforceable, not a prompt convention.
 */
export const approvalValid = (e: LabelEvent): boolean =>
  e.label.startsWith('sdd:') && isApprovalState(e.label.slice(4)) && !e.actorIsBot && !/\[bot\]$/.test(e.actor) && CAN_APPROVE.includes(e.permission)
