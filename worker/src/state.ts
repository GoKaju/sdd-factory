import { mkdirSync } from 'node:fs'
import { DatabaseSync } from 'node:sqlite'
import { join } from 'node:path'

export type JobStatus = 'running' | 'done' | 'failed' | 'timeout' | 'quota'

export interface JobRecord {
  id: number
  repo: string
  issue: number
  phases: string
  stateAtStart: string
  issueUpdatedAt: string
  status: JobStatus
  startedAt: string
  finishedAt: string | null
  logPath: string
  note: string | null
}

/** Durable memory of the worker: what ran, for which issue, against which issue revision. */
export class JobStore {
  private readonly db: DatabaseSync

  constructor(home: string) {
    mkdirSync(home, { recursive: true })
    this.db = new DatabaseSync(join(home, 'jobs.sqlite'))
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS jobs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        repo TEXT NOT NULL,
        issue INTEGER NOT NULL,
        phases TEXT NOT NULL,
        state_at_start TEXT NOT NULL,
        issue_updated_at TEXT NOT NULL,
        status TEXT NOT NULL,
        started_at TEXT NOT NULL,
        finished_at TEXT,
        log_path TEXT NOT NULL,
        note TEXT
      );
      CREATE INDEX IF NOT EXISTS jobs_issue ON jobs (repo, issue, started_at);
    `)
    // A worker that died mid-job leaves 'running' rows behind; they are stale by definition on start.
    this.db.prepare(`UPDATE jobs SET status = 'failed', finished_at = ?, note = 'worker restarted' WHERE status = 'running'`)
      .run(new Date().toISOString())
  }

  start(j: Omit<JobRecord, 'id' | 'status' | 'startedAt' | 'finishedAt' | 'note'>): number {
    const r = this.db.prepare(
      `INSERT INTO jobs (repo, issue, phases, state_at_start, issue_updated_at, status, started_at, log_path)
       VALUES (?, ?, ?, ?, ?, 'running', ?, ?)`,
    ).run(j.repo, j.issue, j.phases, j.stateAtStart, j.issueUpdatedAt, new Date().toISOString(), j.logPath)
    return Number(r.lastInsertRowid)
  }

  finish(id: number, status: JobStatus, note?: string): void {
    this.db.prepare(`UPDATE jobs SET status = ?, finished_at = ?, note = ? WHERE id = ?`)
      .run(status, new Date().toISOString(), note ?? null, id)
  }

  running(repo: string, issue: number): boolean {
    const r = this.db.prepare(`SELECT 1 FROM jobs WHERE repo = ? AND issue = ? AND status = 'running' LIMIT 1`).get(repo, issue)
    return r !== undefined
  }

  runningCount(): number {
    const r = this.db.prepare(`SELECT COUNT(*) AS n FROM jobs WHERE status = 'running'`).get() as { n: number }
    return r.n
  }

  /**
   * True when the same phases already ran for this issue in this state and the issue has not
   * changed since: the previous run did not move the state (it failed or the phase decided to
   * stop), so running again without new input would only repeat the failure.
   */
  alreadyTried(repo: string, issue: number, state: string, issueUpdatedAt: string): boolean {
    const r = this.db.prepare(
      `SELECT status FROM jobs WHERE repo = ? AND issue = ? AND state_at_start = ? AND issue_updated_at = ?
       AND status <> 'running' ORDER BY id DESC LIMIT 1`,
    ).get(repo, issue, state, issueUpdatedAt) as { status: JobStatus } | undefined
    return r !== undefined
  }

  recent(limit = 20): JobRecord[] {
    return this.db.prepare(
      `SELECT id, repo, issue, phases, state_at_start AS stateAtStart, issue_updated_at AS issueUpdatedAt,
              status, started_at AS startedAt, finished_at AS finishedAt, log_path AS logPath, note
       FROM jobs ORDER BY id DESC LIMIT ?`,
    ).all(limit) as unknown as JobRecord[]
  }
}
