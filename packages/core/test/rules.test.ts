import assert from 'node:assert/strict'
import { test } from 'node:test'
import { autoApproveFromConstitution, budgetMinutes, chooseTier, decide, designClean, raise, sddConfigFromJson, specClean, summaryClean, tierFor, type IssueSnapshot } from '../src/index.ts'

const base: IssueSnapshot = {
  number: 1, type: 'Feature', state: null, updatedAt: '2026-09-03T00:00:00Z',
  newCommentSinceTriage: false, triageClean: false, taskComplete: false, reviewPassed: false, idleMinutes: 0, artifactClean: true, size: null, title: "t", reviewCycles: 0,
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

test('delegated Spec/Design/Task approve only when the artifact is verifiably clean', () => {
  const all = { ...o, autoApprove: new Set(['Spec', 'Design', 'Task'] as const) }
  assert.equal(decide({ ...base, state: 'spec', artifactClean: false }, all), null)
  assert.equal(decide({ ...base, state: 'design', artifactClean: false }, all), null)
  assert.equal(decide({ ...base, state: 'task', artifactClean: false }, all), null)
  assert.equal(decide({ ...base, state: 'spec', artifactClean: true }, all)?.approve, 'spec-approved')
})
test('cleanliness predicates', () => {
  assert.equal(summaryClean('Spec entregada. Completeness PASS.'), true)
  assert.equal(summaryClean('Completeness FAIL: 2 BLOCKER'), false)
  assert.equal(summaryClean('Quedan dos preguntas abiertas'), false)
  assert.equal(specClean('# S\n## Open questions\n\nNinguna bloqueante.\n- [x] decidido\n'), true)
  assert.equal(specClean('# S\n## Open questions\n- [ ] ¿qué pasa si…?\n'), false)
  assert.equal(specClean('# S\n## Open questions\n- TBD\n'), false)
  assert.equal(designClean('## Decisions\n| a | b | confirmada por el humano |'), true)
  assert.equal(designClean('| completedAt | pendiente de confirmación humana en el Gate 2 |'), false)
})

test('Spanish "todo" is not a TODO placeholder', () => {
  assert.equal(designClean('TSK-014 exige todo o nada; la ocurrencia se crea en el mismo saveAll.'), true)
  assert.equal(designClean('| pendiente | TODO: decidir |'), false)
  assert.equal(specClean('## Open questions\nTodo resuelto.\n'), true)
  assert.equal(specClean('## Open questions\n- TODO\n'), false)
})

test('.sdd/config.json: delegated approvals and tiers, unknown values ignored', () => {
  const c = sddConfigFromJson(JSON.stringify({ approvals: { auto: ['Spec', 'Design', 'Task', 'Bogus'] }, intelligence: { implement: 'strong', review: 'standard', task: 'huge' } }))
  assert.deepEqual([...c.autoApprove], ['Spec', 'Design', 'Task'])
  assert.deepEqual(c.intelligence, { implement: 'strong', review: 'standard' })
  const bySize = sddConfigFromJson(JSON.stringify({ intelligence: { implement: { S: 'standard', M: 'standard', L: 'strong', default: 'strong' }, spec: 'strong' } }))
  assert.equal(tierFor(bySize.intelligence.implement, 'M', 'strong'), 'standard')
  assert.equal(tierFor(bySize.intelligence.implement, 'L', 'strong'), 'strong')
  assert.equal(tierFor(bySize.intelligence.implement, null, 'light'), 'strong')
  assert.equal(tierFor(bySize.intelligence.spec, 'S', 'standard'), 'strong')
  assert.equal(tierFor(undefined, 'S', 'standard'), 'standard')
  assert.deepEqual([...sddConfigFromJson('{}').autoApprove], [])
})

test('auto tier: floors are never lowered, raises stop at strong, frontier only by floor', () => {
  const none = { rework: false, reviewCycles: 0, recentFailure: false }
  assert.equal(chooseTier('standard', 'auto', 'implement', none, 3).tier, 'standard')
  assert.equal(chooseTier('standard', 'auto', 'implement', { ...none, rework: true }, 3).tier, 'strong')
  assert.equal(chooseTier('strong', 'auto', 'implement', { ...none, rework: true, recentFailure: true }, 3).tier, 'strong')
  assert.equal(chooseTier('standard', 'auto', 'review', { ...none, reviewCycles: 2 }, 3).tier, 'strong')
  assert.equal(chooseTier('standard', 'auto', 'spec', { ...none, rework: true }, 3).tier, 'standard')
  assert.equal(chooseTier('standard', 'auto', 'triage', { ...none, recentFailure: true }, 3).tier, 'strong')
  assert.equal(chooseTier('standard', 'fixed', 'implement', { ...none, rework: true, recentFailure: true }, 3).tier, 'standard')
  assert.equal(chooseTier('frontier', 'auto', 'spec', none, 3).tier, 'frontier')
  assert.equal(raise('strong'), 'strong'); assert.equal(raise('frontier'), 'frontier')
  const c = sddConfigFromJson(JSON.stringify({ intelligence: { mode: 'fixed', spec: 'frontier' }, review: { maxReworkCycles: 2 } }))
  assert.equal(c.intelligenceMode, 'fixed'); assert.equal(c.maxReworkCycles, 2); assert.equal(c.intelligence.spec, 'frontier')
})

test('frontier gets a longer wall-clock budget, others keep the phase default', () => {
  assert.equal(budgetMinutes('design', 'strong'), 30)
  assert.equal(budgetMinutes('design', 'frontier'), 45)
  assert.equal(budgetMinutes('implement', 'frontier'), 135)
  assert.equal(budgetMinutes('triage'), 15)
})
