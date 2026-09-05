/**
 * Messages between a worker and the control plane. The embedded worker never sends them, but it
 * builds the same `Job` records, so both orchestrators speak of the same thing.
 *
 * Transport (decided 2026-09-04): HTTP for anything transactional (register, heartbeat, lease,
 * result); AppSync Events for push (`fleet/<workerId>`), progress (`jobs/<jobId>/progress`) and
 * the live dashboard (`dashboard/*`).
 */
import type { IssueType, Phase, SddState, Tier } from './types.ts'

export const PROTOCOL_VERSION = 1

export type JobStatus = 'queued' | 'leased' | 'running' | 'done' | 'failed' | 'timeout' | 'quota' | 'lost' | 'cancelled'
/** Terminal outcomes a worker can report; `lost` and `cancelled` are decided by the control plane. */
export type RunOutcome = 'done' | 'failed' | 'timeout' | 'quota'

export interface Job {
  id: string
  repo: string
  issue: number
  issueType: IssueType | null
  /** the SDD state the issue had when the job was created; the job is stale if it changed */
  stateAtStart: SddState | null
  phases: Phase[]
  tier: Tier
  tierReason: string
  /** lower runs first; see `priorityOf` */
  priority: number
  status: JobStatus
  attempt: number
  createdAt: string
  /** worker that holds the lease, while leased or running */
  workerId: string | null
  leaseUntil: string | null
  /** why the job exists, for the log and the dashboard */
  reason: string
}

/** What a worker says about itself when it registers and on every heartbeat. */
export interface WorkerRegistration {
  name: string
  os: 'darwin' | 'linux' | 'win32'
  slots: number
  /** tiers this worker can serve, i.e. keys of its tier→model map */
  tiers: Tier[]
  /** repositories already cloned on this worker (affinity), `owner/name` */
  repos: string[]
  pluginVersion: string
  protocolVersion: number
}

export interface WorkerRecord extends WorkerRegistration {
  id: string
  lastSeenAt: string
  paused: boolean
  /** ids of jobs the worker currently holds */
  running: string[]
}

export interface Heartbeat {
  workerId: string
  at: string
  running: { jobId: string; phase: Phase; startedAt: string; lastLine: string | null }[]
  /** the worker is draining: finish what runs, take nothing new */
  draining: boolean
}

export interface LeaseRequest {
  workerId: string
  /** free slots right now */
  free: number
}

export interface LeaseGrant {
  job: Job
  /** short-lived GitHub installation token scoped to the job's repository */
  installationToken: string
  tokenExpiresAt: string
  branch: string | null
  timeoutMinutes: number
  leaseSeconds: number
}

export interface JobResult {
  jobId: string
  workerId: string
  outcome: RunOutcome
  summary: string
  costUsd: number | null
  turns: number | null
  startedAt: string
  finishedAt: string
  /** per phase actually run, in order */
  phases: { phase: Phase; outcome: RunOutcome; durationMs: number; costUsd: number | null; turns: number | null }[]
}

/** Pushed by the control plane on `fleet/<workerId>`. */
export type FleetEvent =
  | { kind: 'cancel'; jobId: string; reason: string }
  | { kind: 'pause'; until: string; reason: string }
  | { kind: 'resume' }
  | { kind: 'drain'; reason: string }

/** Published by the worker on `jobs/<jobId>/progress`. */
export interface ProgressEvent { jobId: string; at: string; phase: Phase; line: string }

export const fleetChannel = (workerId: string): string => `fleet/${workerId}`
export const progressChannel = (jobId: string): string => `jobs/${jobId}/progress`
export const dashboardChannel = (repo: string): string => `dashboard/${repo.replace('/', '__')}`
