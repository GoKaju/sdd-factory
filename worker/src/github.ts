import { execFile } from 'node:child_process'
import { promisify } from 'node:util'
import type { IssueSnapshot, IssueType, SddState } from './rules.ts'

const run = promisify(execFile)

/** Runs a command and returns trimmed stdout; throws with stderr on failure. */
export const sh = async (cmd: string, args: string[], cwd?: string): Promise<string> => {
  const { stdout } = await run(cmd, args, { cwd, maxBuffer: 16 * 1024 * 1024 })
  return stdout.trim()
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
      taskComplete: state === 'design-approved' ? await commentClean(pluginDir, repoPath, i.number, 'sdd:task') : false,
      reviewPassed: state === 'final-review' ? await reviewPassed(pluginDir, repoPath, i.number) : false,
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
