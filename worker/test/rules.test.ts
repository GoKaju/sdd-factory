import assert from 'node:assert/strict'
import { test } from 'node:test'
import { decide, type IssueSnapshot } from '../src/rules.ts'

const base: IssueSnapshot = {
  number: 1, type: 'Feature', state: null, updatedAt: '2026-09-03T00:00:00Z',
  newCommentSinceTriage: false, taskComplete: false, idleMinutes: 0,
}
const o = { autoSpec: false, staleImplementingMinutes: 45 }

test('a new issue is triaged', () => {
  assert.deepEqual(decide(base, o)?.phases, ['triage'])
})
test('triage waits for the author unless a new comment arrived', () => {
  assert.equal(decide({ ...base, state: 'triage' }, o), null)
  assert.deepEqual(decide({ ...base, state: 'triage', newCommentSinceTriage: true }, o)?.phases, ['triage'])
})
test('ready: Feature/Change wait for a human unless autoSpec; Bug/Task jump to task', () => {
  assert.equal(decide({ ...base, state: 'ready' }, o), null)
  assert.deepEqual(decide({ ...base, state: 'ready' }, { ...o, autoSpec: true })?.phases, ['spec'])
  assert.deepEqual(decide({ ...base, state: 'ready', type: 'Bug' }, o)?.phases, ['task'])
  assert.deepEqual(decide({ ...base, state: 'ready', type: 'Task' }, o)?.phases, ['task'])
})
test('human-approved states chain the next phase', () => {
  assert.deepEqual(decide({ ...base, state: 'spec-approved' }, o)?.phases, ['design'])
  assert.deepEqual(decide({ ...base, state: 'design-approved' }, o)?.phases, ['task'])
  assert.deepEqual(decide({ ...base, state: 'task-approved' }, o)?.phases, ['implement', 'review'])
})
test('document-only amendment goes straight to review', () => {
  assert.deepEqual(decide({ ...base, state: 'design-approved', taskComplete: true }, o)?.phases, ['review'])
})
test('states that wait for a human run nothing', () => {
  for (const state of ['spec', 'design', 'task', 'final-review'] as const) {
    assert.equal(decide({ ...base, state }, o), null, state)
  }
})
test('implementing resumes only when stale', () => {
  assert.equal(decide({ ...base, state: 'implementing', idleMinutes: 10 }, o), null)
  assert.deepEqual(decide({ ...base, state: 'implementing', idleMinutes: 50 }, o)?.phases, ['implement', 'review'])
})
