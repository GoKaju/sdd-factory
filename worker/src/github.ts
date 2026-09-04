import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { execFile, spawn } from 'node:child_process'
import { promisify } from 'node:util'
import { designClean, specClean, type IssueSnapshot, type IssueType, type SddState, type Size } from './rules.ts'

const run = promisify(execFile)

/** Runs a command and returns trimmed stdout; throws with stderr on failure. */
export const sh = async (cmd: string, args: string[], cwd?: string, input?: string): Promise<string> => {
  if (input === undefined) {
    const { stdout } = await run(cmd, args, { cwd, maxBuffer: 16 * 1024 * 1024 })
    return stdout.trim()
  }
  // with stdin: spawn, feed the input, collect stdout
  return new Promise((resolve, reject) => {
    const child = spawn(cmd, args, { cwd, stdio: ['pipe', 'pipe', 'pipe'] })
    let out = ''; let err = ''
    child.stdout.on('data', (d: Buffer) => { out += d.toString() })
    child.stderr.on('data', (d: Buffer) => { err += d.toString() })
    child.on('error', reject)
    child.on('close', (code) => (code === 0 ? resolve(out.trim()) : reject(new Error(`${cmd} ${args.join(' ')} exited ${code}: ${err.trim()}`))))
    child.stdin.end(input)
  })
}

interface RawIssue {
  number: number
  title: string
  updated_at: string
  labels: { name: string }[]
  type: { name: string } | null
  pull_request?: unknown
}

const STATES: SddState[] = [
  'triage', 'ready', 'spec', 'spec-approved', 'design', 'design-approved',
  'task', 'task-approved', 'implementing', 'in-review', 'rework', 'final-review',
]
const TYPES: IssueType[] = ['Feature', 'Change', 'Bug', 'Task', 'Constitution']

const stateOf = (labels: { name: string }[]): SddState | null => {
  const found = labels.map((l) => l.name).filter((n) => n.startsWith('sdd:')).map((n) => n.slice(4))
  let best: SddState | null = null
  for (const s of STATES) if (found.includes(s)) best = s
  return best
}

const typeOf = (t: { name: string } | null): IssueType | null =>
  t && (TYPES as string[]).includes(t.name) ? (t.name as IssueType) : null

export interface OpenIssue extends IssueSnapshot {
  title: string
}

/** Every open issue of the repository with its SDD state, native type and comment-derived facts. */
export const openIssues = async (repo: string, pluginDir: string, repoPath: string): Promise<OpenIssue[]> => {
  const raw = JSON.parse(
    await sh('gh', ['api', `repos/${repo}/issues?state=open&per_page=100`, '--paginate']),
  ) as RawIssue[]
  const issues = raw.filter((i) => !i.pull_request)
  const out: OpenIssue[] = []
  for (const i of issues) {
    const state = stateOf(i.labels)
    const idleMinutes = Math.floor((Date.now() - Date.parse(i.updated_at)) / 60000)
    out.push({
      number: i.number,
      title: i.title,
      type: typeOf(i.type),
      state,
      updatedAt: i.updated_at,
      idleMinutes,
      newCommentSinceTriage: state === 'triage' ? await newCommentSinceTriage(repo, i.number) : false,
      triageClean: state === 'triage' ? await commentClean(pluginDir, repoPath, i.number, 'sdd:triage') : false,
      taskComplete: state === 'design-approved' ? await taskStillValid(repo, pluginDir, repoPath, i.number) : false,
      reviewPassed: state === 'final-review' ? await reviewPassed(pluginDir, repoPath, i.number) : false,
      artifactClean: await artifactClean(repo, pluginDir, repoPath, i.number, state),
      size: await triageSize(pluginDir, repoPath, i.number),
      reviewCycles: ['rework', 'in-review', 'final-review', 'implementing', 'task-approved'].includes(state ?? '') ? await reviewCycles(pluginDir, repoPath, i.number) : 0,
    })
  }
  return out
}

interface RawComment { body: string; created_at: string; updated_at: string }

/**
 * New input for triage since the triage comment was last written: a comment by anyone other than
 * the factory, or an edit of the issue title/body. Body edits are not comments nor timeline events;
 * GitHub exposes them only as `lastEditedAt` on the Issue (GraphQL).
 */
const newCommentSinceTriage = async (repo: string, issue: number): Promise<boolean> => {
  const comments = JSON.parse(
    await sh('gh', ['api', `repos/${repo}/issues/${issue}/comments?per_page=100`, '--paginate']),
  ) as RawComment[]
  const triage = comments.find((c) => c.body.startsWith('<!-- sdd:triage -->'))
  if (!triage) return true
  const mark = Date.parse(triage.updated_at)
  if (comments.some((c) => !c.body.startsWith('<!-- sdd:') && Date.parse(c.created_at) > mark)) return true
  const edited = await lastEditedAt(repo, issue)
  return edited !== null && edited > mark
}

const lastEditedAt = async (repo: string, issue: number): Promise<number | null> => {
  const [owner, name] = repo.split('/')
  const q = `{ repository(owner:"${owner}", name:"${name}") { issue(number:${issue}) { lastEditedAt } } }`
  try {
    const out = await sh('gh', ['api', 'graphql', '-f', `query=${q}`, '--jq', '.data.repository.issue.lastEditedAt'])
    return out && out !== 'null' ? Date.parse(out) : null
  } catch {
    return null
  }
}

/** The marked comment exists and has no unchecked box. */
const commentClean = async (pluginDir: string, repoPath: string, issue: number, marker: string): Promise<boolean> => {
  try {
    const id = await sh(`${pluginDir}/scripts/sdd-comment.sh`, ['find', String(issue), marker], repoPath)
    if (!id) return false
    const open = await sh(`${pluginDir}/scripts/sdd-comment.sh`, ['open', String(issue), marker], repoPath)
    return open === '0'
  } catch {
    return false
  }
}

/**
 * The Task is complete AND still valid: every step ticked, and the Task comment is newer than the last
 * change to docs/ on the PR branch. A Task written for a previous spec/design is stale even if fully
 * ticked (sdd-pilot#12: the shortcut to review skipped the re-implementation of a rewritten spec).
 */
const taskStillValid = async (repo: string, pluginDir: string, repoPath: string, issue: number): Promise<boolean> => {
  try {
    if (!(await commentClean(pluginDir, repoPath, issue, 'sdd:task'))) return false
    const comments = JSON.parse(await sh('gh', ['api', `repos/${repo}/issues/${issue}/comments?per_page=100`, '--paginate'])) as RawComment[]
    const task = comments.find((c) => c.body.startsWith('<!-- sdd:task -->'))
    if (!task) return false
    const branch = await sh(`${pluginDir}/scripts/sdd-pr.sh`, ['branch', String(issue)], repoPath)
    if (!branch) return true
    const lastDocs = await sh('gh', ['api', `repos/${repo}/commits?sha=${encodeURIComponent(branch)}&path=docs&per_page=1`, '--jq', '.[0].commit.committer.date'])
    return !lastDocs || Date.parse(task.updated_at) > Date.parse(lastDocs)
  } catch {
    return false
  }
}

/** Number of review cycles with published gate results on the issue's PR. */
const reviewCycles = async (pluginDir: string, repoPath: string, issue: number): Promise<number> => {
  try {
    const pr = await sh(`${pluginDir}/scripts/sdd-pr.sh`, ['find', String(issue)], repoPath)
    if (!pr) return 0
    let c = 0
    while (c < 10 && (await sh(`${pluginDir}/scripts/sdd-gate-result.sh`, ['list', pr, String(c)], repoPath)) !== '') c++
    return c
  } catch { return 0 }
}

/** S/M/L from the triage comment (`**Tamaño:** M` / `**Size:** M`), null when there is no triage yet. */
const triageSize = async (pluginDir: string, repoPath: string, issue: number): Promise<Size | null> => {
  try {
    const body = await sh(`${pluginDir}/scripts/sdd-comment.sh`, ['get', String(issue), 'sdd:triage'], repoPath)
    const m = /\*\*(?:Tamaño|Size):\*\*\s*([SML])\b/.exec(body)
    return m ? (m[1] as Size) : null
  } catch {
    return null
  }
}

/** Cleanliness of the artifact that waits for approval in this state (see IssueSnapshot.artifactClean). */
const artifactClean = async (repo: string, pluginDir: string, repoPath: string, issue: number, state: SddState | null): Promise<boolean> => {
  try {
    if (state === 'task') {
      const id = await sh(`${pluginDir}/scripts/sdd-comment.sh`, ['find', String(issue), 'sdd:task'], repoPath)
      if (!id) return false
      const body = await sh(`${pluginDir}/scripts/sdd-comment.sh`, ['get', String(issue), 'sdd:task'], repoPath)
      return /^- \[[ x]\] \*\*T1\*\*/m.test(body)
    }
    if (state !== 'spec' && state !== 'design') return false
    const pr = await sh(`${pluginDir}/scripts/sdd-pr.sh`, ['find', String(issue)], repoPath)
    if (!pr) return false
    const branch = await sh(`${pluginDir}/scripts/sdd-pr.sh`, ['branch', String(issue)], repoPath)
    const files = (await sh('gh', ['pr', 'diff', pr, '--name-only'], repoPath)).split('\n')
    const want = state === 'spec' ? /^docs\/.+\/spec\.md$/ : /^docs\/.+\/design\.md$/
    const docs = files.filter((f) => want.test(f))
    if (docs.length === 0) return false
    for (const path of docs) {
      const text = await sh('gh', ['api', `repos/${repo}/contents/${path}?ref=${branch}`, '-H', 'Accept: application/vnd.github.raw'])
      if (!(state === 'spec' ? specClean(text) : designClean(text))) return false
    }
    return true
  } catch {
    return false
  }
}

/** The PR is out of draft and the latest review cycle aggregates to PASS. */
const reviewPassed = async (pluginDir: string, repoPath: string, issue: number): Promise<boolean> => {
  try {
    const pr = await sh(`${pluginDir}/scripts/sdd-pr.sh`, ['find', String(issue)], repoPath)
    if (!pr) return false
    const draft = await sh('gh', ['pr', 'view', pr, '--json', 'isDraft', '-q', '.isDraft'], repoPath)
    if (draft === 'true') return false
    const rows = await sh(`${pluginDir}/scripts/sdd-gate-result.sh`, ['list', pr], repoPath)
    const cycles = await sh('gh', ['api', `repos/${await nameWithOwner(repoPath)}/issues/${pr}/comments`, '--paginate', '--jq', '.[].body'], repoPath)
    const nums = [...cycles.matchAll(/<!-- sdd:gate:[a-z-]+:(\d+) -->/g)].map((m) => Number(m[1]))
    if (rows === '' || nums.length === 0) return false
    const latest = String(Math.max(...nums))
    return (await sh(`${pluginDir}/scripts/sdd-gate-result.sh`, ['aggregate', pr, latest], repoPath)) === 'PASS'
  } catch {
    return false
  }
}

const nameWithOwner = (repoPath: string): Promise<string> => sh('gh', ['repo', 'view', '--json', 'nameWithOwner', '-q', '.nameWithOwner'], repoPath)

/** The worker assigns the issue to the account `gh` runs as while it owns it, and hands it back when a human must act. */
export const setAssignee = async (repoPath: string, issue: number, on: boolean): Promise<void> => {
  try { await sh('gh', ['issue', 'edit', String(issue), on ? '--add-assignee' : '--remove-assignee', '@me'], repoPath) } catch { /* visibility only */ }
}

export const setWorking = async (pluginDir: string, repoPath: string, issue: number, on: boolean): Promise<void> => {
  try { await sh(`${pluginDir}/scripts/sdd-state.sh`, ['working', String(issue), on ? 'on' : 'off'], repoPath) } catch { /* visibility only */ }
}

export const setState = async (pluginDir: string, repoPath: string, issue: number, state: string): Promise<void> => {
  await sh(`${pluginDir}/scripts/sdd-state.sh`, ['set', String(issue), state], repoPath)
}

export const mergePr = async (pluginDir: string, repoPath: string, issue: number): Promise<string> => {
  const pr = await sh(`${pluginDir}/scripts/sdd-pr.sh`, ['find', String(issue)], repoPath)
  if (!pr) throw new Error(`no PR linked to #${issue}`)
  await sh('gh', ['pr', 'merge', pr, '--squash', '--delete-branch'], repoPath)
  return pr
}

export const isClosed = async (repo: string, issue: number): Promise<boolean> =>
  (await sh('gh', ['api', `repos/${repo}/issues/${issue}`, '--jq', '.state'])) === 'closed'

export const prBranch = async (pluginDir: string, repoPath: string, issue: number): Promise<string | null> => {
  try {
    const n = await sh(`${pluginDir}/scripts/sdd-pr.sh`, ['find', String(issue)], repoPath)
    if (!n) return null
    return await sh(`${pluginDir}/scripts/sdd-pr.sh`, ['branch', String(issue)], repoPath)
  } catch {
    return null
  }
}

export const comment = async (repo: string, issue: number, body: string): Promise<void> => {
  await sh('gh', ['issue', 'comment', String(issue), '--repo', repo, '--body', body])
}

/**
 * The ledger lives as ONE marked comment on the issue (the unit of work), rewritten after every phase,
 * plus ONE marked one-line comment on the PR that points to it. Both are mechanical upserts.
 */
export const upsertLedger = async (repo: string, pluginDir: string, repoPath: string, issue: number, block: string, line: string): Promise<void> => {
  // sdd-comment.sh requires the body to start with the marker it is filed under
  await sh(`${pluginDir}/scripts/sdd-comment.sh`, ['upsert', String(issue), 'sdd:ledger', '-'], repoPath, `<!-- sdd:ledger -->\n${block}\n`)
  const pr = await sh(`${pluginDir}/scripts/sdd-pr.sh`, ['find', String(issue)], repoPath)
  if (pr) await sh(`${pluginDir}/scripts/sdd-comment.sh`, ['upsert', pr, 'sdd:ledger-line', '-'], repoPath, `<!-- sdd:ledger-line -->\n${line}\n`)
}

/** The constitution's Language (Identity section); 'en' when unknown. */
export const constitutionLanguage = (repoPath: string): 'es' | 'en' => {
  try {
    const t = readFileSync(join(repoPath, 'docs', 'constitution.md'), 'utf8')
    return /\*\*Language:\*\*\s*es\b/i.test(t) || /^-?\s*Language:\s*es\b/im.test(t) ? 'es' : 'en'
  } catch { return 'en' }
}
