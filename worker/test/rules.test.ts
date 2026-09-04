import assert from 'node:assert/strict'
import { test } from 'node:test'
import { autoApproveFromConstitution, decide, type IssueSnapshot } from '../src/rules.ts'

const base: IssueSnapshot = {
  number: 1, type: 'Feature', state: null, updatedAt: '2026-09-03T00:00:00Z',
  newCommentSinceTriage: false, triageClean: false, taskComplete: false, reviewPassed: false, idleMinutes: 0,
}
const o = { autoSpec: false, staleImplementingMinutes: 45, autoApprove: new Set<never>() }

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

test('auto-approval is off unless the constitution opts in', () => {
  assert.equal(decide({ ...base, state: 'triage', triageClean: true }, o), null)
  assert.equal(decide({ ...base, state: 'spec' }, o), null)
  const all = { ...o, autoApprove: new Set(['Intake', 'Spec', 'Design', 'Task', 'Final'] as const) }
  assert.equal(decide({ ...base, state: 'triage', triageClean: true }, all)?.approve, 'ready')
  assert.equal(decide({ ...base, state: 'triage', triageClean: false }, all), null)
  assert.equal(decide({ ...base, state: 'spec' }, all)?.approve, 'spec-approved')
  assert.equal(decide({ ...base, state: 'design' }, all)?.approve, 'design-approved')
  assert.equal(decide({ ...base, state: 'task' }, all)?.approve, 'task-approved')
  assert.equal(decide({ ...base, state: 'final-review', reviewPassed: true }, all)?.merge, true)
  assert.equal(decide({ ...base, state: 'final-review', reviewPassed: false }, all), null)
})
test('the constitution line is parsed leniently', () => {
  assert.deepEqual([...autoApproveFromConstitution('- **Auto-approved gates:** Intake, Task')], ['Intake', 'Task'])
  assert.deepEqual([...autoApproveFromConstitution('- **Auto-approved gates:** none')], [])
  assert.deepEqual([...autoApproveFromConstitution('- **Auto-approved gates:** Intake · Spec · Design · Task · Final')], ['Intake', 'Spec', 'Design', 'Task', 'Final'])
  assert.deepEqual([...autoApproveFromConstitution('no such line')], [])
})

test('Review Gate names are never mistaken for phase gates', () => {
  assert.deepEqual([...autoApproveFromConstitution('- **Auto-approved phase gates:** Spec Compliance, Design & Architecture, Task')], ['Task'])
  assert.deepEqual([...autoApproveFromConstitution('- **Auto-approved phase gates:** Spec, Design')], ['Spec', 'Design'])
})
test('a Constitution amendment is never auto-merged', () => {
  const all = { ...o, autoApprove: new Set(['Final'] as const) }
  assert.equal(decide({ ...base, type: 'Constitution', state: 'final-review', reviewPassed: true }, all), null)
  assert.equal(decide({ ...base, type: 'Task', state: 'final-review', reviewPassed: true }, all)?.merge, true)
})
