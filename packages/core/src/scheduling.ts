import type { Job, RunOutcome, WorkerRecord } from './protocol.ts'
import type { IssueType } from './types.ts'

/** Lower runs first. A Constitution amendment changes the rules for everything behind it. */
export const priorityOf = (t: IssueType | null): number => {
  switch (t) {
    case 'Constitution': return 0
    case 'Bug': return 1
    case 'Change': return 2
    case 'Feature': return 3
    case 'Task': return 4
    default: return 5
  }
}

/** Queue order: priority, then age. Stable for equal keys. */
export const compareJobs = (a: Job, b: Job): number => a.priority - b.priority || a.createdAt.localeCompare(b.createdAt) || a.id.localeCompare(b.id)

export interface FleetLimits {
  /** implement+review jobs allowed at once per repository, so CI is not saturated */
  maxHeavyPerRepo: number
  /** workers below this plugin version take no job */
  minPluginVersion: string
}

const HEAVY = new Set(['implement', 'review'])
export const isHeavy = (j: Pick<Job, 'phases'>): boolean => j.phases.some((p) => HEAVY.has(p))

/** semver-ish compare on dotted numbers; anything unparsable is treated as 0. */
export const versionAtLeast = (v: string, min: string): boolean => {
  const n = (s: string): number[] => s.split('.').map((x) => Number.parseInt(x, 10) || 0)
  const a = n(v); const b = n(min)
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    const d = (a[i] ?? 0) - (b[i] ?? 0)
    if (d !== 0) return d > 0
  }
  return true
}

/** Can this worker take this job at all? Capacity is checked by the caller with `free`. */
export const eligible = (w: WorkerRecord, j: Job, limits: FleetLimits): boolean =>
  !w.paused && w.tiers.includes(j.tier) && versionAtLeast(w.pluginVersion, limits.minPluginVersion)

/**
 * Picks the next job for a worker asking for one: highest priority first, preferring jobs of
 * repositories the worker already has cloned. Invariants enforced here: one live job per issue,
 * per-repo heavy limit, eligibility.
 */
export const nextJob = (queue: readonly Job[], live: readonly Job[], w: WorkerRecord, limits: FleetLimits): Job | null => {
  const liveIssues = new Set(live.map((j) => `${j.repo}#${j.issue}`))
  const heavyByRepo = new Map<string, number>()
  for (const j of live) if (isHeavy(j)) heavyByRepo.set(j.repo, (heavyByRepo.get(j.repo) ?? 0) + 1)
  const candidates = queue
    .filter((j) => j.status === 'queued' && !liveIssues.has(`${j.repo}#${j.issue}`) && eligible(w, j, limits))
    .filter((j) => !isHeavy(j) || (heavyByRepo.get(j.repo) ?? 0) < limits.maxHeavyPerRepo)
    .sort(compareJobs)
  if (candidates.length === 0) return null
  const top = candidates[0] as Job
  // affinity only reorders within the top priority band: a cloned repo never beats a Bug with a Feature
  const band = candidates.filter((j) => j.priority === top.priority)
  return band.find((j) => w.repos.includes(j.repo)) ?? top
}

export const leaseExpired = (j: Pick<Job, 'status' | 'leaseUntil'>, now: Date): boolean =>
  (j.status === 'leased' || j.status === 'running') && j.leaseUntil !== null && Date.parse(j.leaseUntil) < now.getTime()

export type FailureCause = 'infrastructure' | 'gate' | 'quota' | 'lost'

/**
 * Only failures the factory caused itself are retried: a lost lease, a timeout, an infrastructure
 * error. A gate verdict is a decision, not an error, and quota is a pause of the worker, not a retry.
 */
export const shouldRetry = (outcome: RunOutcome | 'lost', cause: FailureCause, attempt: number, maxAttempts = 3): boolean => {
  if (attempt >= maxAttempts) return false
  if (outcome === 'done' || outcome === 'quota') return false
  if (cause === 'gate' || cause === 'quota') return false
  return outcome === 'lost' || outcome === 'timeout' || cause === 'infrastructure' || cause === 'lost'
}

/** Backoff in seconds before the n-th retry: 1, 4, 9 … minutes, capped at 30. */
export const retryDelaySeconds = (attempt: number): number => Math.min(attempt * attempt * 60, 1800)
