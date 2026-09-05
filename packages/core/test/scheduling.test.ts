import assert from 'node:assert/strict'
import { test } from 'node:test'
import { approvalValid, compareJobs, leaseExpired, nextJob, priorityOf, retryDelaySeconds, shouldRetry, versionAtLeast, type Job, type WorkerRecord } from '../src/index.ts'

const job = (o: Partial<Job>): Job => ({
  id: 'j', repo: 'o/r', issue: 1, issueType: 'Feature', stateAtStart: 'task-approved', phases: ['implement', 'review'], tier: 'standard', tierReason: 'floor',
  priority: priorityOf(o.issueType ?? 'Feature'), status: 'queued', attempt: 1, createdAt: '2026-09-04T00:00:00Z', workerId: null, leaseUntil: null, reason: 't', ...o,
})
const worker = (o: Partial<WorkerRecord> = {}): WorkerRecord => ({
  id: 'w', name: 'mac', os: 'darwin', slots: 2, tiers: ['light', 'standard', 'strong'], repos: ['o/r'], pluginVersion: '0.7.0', protocolVersion: 1,
  lastSeenAt: '2026-09-04T00:00:00Z', paused: false, running: [], ...o,
})
const limits = { maxHeavyPerRepo: 1, minPluginVersion: '0.7.0' }

test('priority: Constitution before Bug before Change before Feature before Task', () => {
  const q = [job({ id: 'a', issueType: 'Task' }), job({ id: 'b', issueType: 'Bug' }), job({ id: 'c', issueType: 'Constitution' }), job({ id: 'd', issueType: 'Feature' })]
  assert.deepEqual([...q].sort(compareJobs).map((j) => j.id), ['c', 'b', 'd', 'a'])
})
test('equal priority: older first', () => {
  const q = [job({ id: 'a', createdAt: '2026-09-04T01:00:00Z' }), job({ id: 'b', createdAt: '2026-09-04T00:00:00Z' })]
  assert.equal(nextJob(q, [], worker(), limits)?.id, 'b')
})
test('one live job per issue, heavy limit per repo', () => {
  const live = [job({ id: 'live', issue: 1, status: 'running', workerId: 'x' })]
  assert.equal(nextJob([job({ id: 'same', issue: 1 })], live, worker(), limits), null, 'same issue')
  assert.equal(nextJob([job({ id: 'other', issue: 2 })], live, worker(), limits), null, 'heavy limit reached')
  assert.equal(nextJob([job({ id: 'other', issue: 2 })], live, worker(), { ...limits, maxHeavyPerRepo: 2 })?.id, 'other')
  assert.equal(nextJob([job({ id: 'light', issue: 2, phases: ['triage'] })], live, worker(), limits)?.id, 'light', 'triage is not heavy')
})
test('eligibility: tier, plugin version, paused', () => {
  assert.equal(nextJob([job({ tier: 'frontier' })], [], worker(), limits), null)
  assert.equal(nextJob([job({})], [], worker({ pluginVersion: '0.6.9' }), limits), null)
  assert.equal(nextJob([job({})], [], worker({ paused: true }), limits), null)
  assert.equal(nextJob([job({})], [], worker(), limits)?.id, 'j')
})
test('affinity reorders only within the top priority band', () => {
  const q = [job({ id: 'far-bug', repo: 'o/other', issueType: 'Bug' }), job({ id: 'near-feature', repo: 'o/r', issueType: 'Feature' })]
  assert.equal(nextJob(q, [], worker(), { ...limits, maxHeavyPerRepo: 5 })?.id, 'far-bug')
  const same = [job({ id: 'far', repo: 'o/other' }), job({ id: 'near', repo: 'o/r' })]
  assert.equal(nextJob(same, [], worker(), { ...limits, maxHeavyPerRepo: 5 })?.id, 'near')
})
test('versions compare numerically', () => {
  assert.equal(versionAtLeast('0.10.0', '0.9.9'), true)
  assert.equal(versionAtLeast('0.6.8', '0.7.0'), false)
  assert.equal(versionAtLeast('1.0', '1.0.0'), true)
})
test('leases and retries', () => {
  const now = new Date('2026-09-04T00:10:00Z')
  assert.equal(leaseExpired(job({ status: 'running', leaseUntil: '2026-09-04T00:05:00Z' }), now), true)
  assert.equal(leaseExpired(job({ status: 'running', leaseUntil: '2026-09-04T00:15:00Z' }), now), false)
  assert.equal(leaseExpired(job({ status: 'queued', leaseUntil: '2026-09-04T00:05:00Z' }), now), false)
  assert.equal(shouldRetry('lost', 'lost', 1), true)
  assert.equal(shouldRetry('timeout', 'infrastructure', 2), true)
  assert.equal(shouldRetry('failed', 'infrastructure', 1), true)
  assert.equal(shouldRetry('failed', 'gate', 1), false, 'a gate verdict is not an error')
  assert.equal(shouldRetry('quota', 'quota', 1), false)
  assert.equal(shouldRetry('lost', 'lost', 3), false, 'max attempts')
  assert.deepEqual([1, 2, 3, 10].map(retryDelaySeconds), [60, 240, 540, 1800])
})
test('only humans with write access approve', () => {
  const ok = { label: 'sdd:spec-approved', actor: 'deiby', actorIsBot: false, permission: 'write' as const }
  assert.equal(approvalValid(ok), true)
  assert.equal(approvalValid({ ...ok, actor: 'sdd-factory[bot]' }), false)
  assert.equal(approvalValid({ ...ok, actorIsBot: true }), false)
  assert.equal(approvalValid({ ...ok, permission: 'triage' }), false)
  assert.equal(approvalValid({ ...ok, label: 'sdd:spec' }), false, 'not an approval state')
  assert.equal(approvalValid({ ...ok, label: 'sdd:ready', permission: 'admin' }), true)
})
