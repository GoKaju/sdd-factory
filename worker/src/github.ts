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
      taskComplete: state === 'design-approved' ? await taskComplete(pluginDir, repoPath, i.number) : false,
    })
  }
  return out
}

interface RawComment { body: string; created_at: string; updated_at: string }

const newCommentSinceTriage = async (repo: string, issue: number): Promise<boolean> => {
  const comments = JSON.parse(
    await sh('gh', ['api', `repos/${repo}/issues/${issue}/comments?per_page=100`, '--paginate']),
  ) as RawComment[]
  const triage = comments.find((c) => c.body.startsWith('<!-- sdd:triage -->'))
  if (!triage) return true
  const mark = Date.parse(triage.updated_at)
  return comments.some((c) => !c.body.startsWith('<!-- sdd:') && Date.parse(c.created_at) > mark)
}

const taskComplete = async (pluginDir: string, repoPath: string, issue: number): Promise<boolean> => {
  try {
    const id = await sh(`${pluginDir}/scripts/sdd-comment.sh`, ['find', String(issue), 'sdd:task'], repoPath)
    if (!id) return false
    const open = await sh(`${pluginDir}/scripts/sdd-comment.sh`, ['open', String(issue), 'sdd:task'], repoPath)
    return open === '0'
  } catch {
    return false
  }
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
