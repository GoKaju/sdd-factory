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
      CREATE TABLE IF NOT EXISTS phases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        job_id INTEGER NOT NULL REFERENCES jobs(id),
        repo TEXT NOT NULL,
        issue INTEGER NOT NULL,
        phase TEXT NOT NULL,
        outcome TEXT NOT NULL,
        started_at TEXT NOT NULL,
        finished_at TEXT NOT NULL,
        duration_ms INTEGER NOT NULL,
        cost_usd REAL,
        turns INTEGER
      );
      CREATE INDEX IF NOT EXISTS phases_issue ON phases (repo, issue, phase);
      CREATE TABLE IF NOT EXISTS holds (
        repo TEXT NOT NULL, issue INTEGER NOT NULL, state TEXT NOT NULL, created_at TEXT NOT NULL,
        PRIMARY KEY (repo, issue, state)
      );
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

  setNote(id: number, note: string): void {
    this.db.prepare(`UPDATE jobs SET note = ? WHERE id = ?`).run(note, id)
  }

  finish(id: number, status: JobStatus, note?: string): void {
    // Keep the last phase summary when the caller has nothing more specific to say (lastPhaseNote depends on it).
    if (note === undefined) this.db.prepare(`UPDATE jobs SET status = ?, finished_at = ? WHERE id = ?`).run(status, new Date().toISOString(), id)
    else this.db.prepare(`UPDATE jobs SET status = ?, finished_at = ?, note = ? WHERE id = ?`).run(status, new Date().toISOString(), note, id)
  }

  /** One row per executed phase: the factory's cost and time ledger. */
  recordPhase(p: { jobId: number; repo: string; issue: number; phase: string; outcome: string; startedAt: string; costUsd: number | null; turns: number | null }): void {
    const finished = new Date()
    this.db.prepare(
      `INSERT INTO phases (job_id, repo, issue, phase, outcome, started_at, finished_at, duration_ms, cost_usd, turns)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    ).run(p.jobId, p.repo, p.issue, p.phase, p.outcome, p.startedAt, finished.toISOString(),
      finished.getTime() - Date.parse(p.startedAt), p.costUsd, p.turns)
  }

  /** Totals per issue: phases run, minutes, dollars, turns. */
  statsByIssue(repo?: string): { repo: string; issue: number; phases: number; minutes: number; usd: number; turns: number }[] {
    return this.db.prepare(
      `SELECT repo, issue, COUNT(*) AS phases, ROUND(SUM(duration_ms) / 60000.0, 1) AS minutes,
              ROUND(COALESCE(SUM(cost_usd), 0), 2) AS usd, COALESCE(SUM(turns), 0) AS turns
       FROM phases ${repo ? 'WHERE repo = ?' : ''} GROUP BY repo, issue ORDER BY repo, issue`,
    ).all(...(repo ? [repo] : [])) as unknown as { repo: string; issue: number; phases: number; minutes: number; usd: number; turns: number }[]
  }

  /** Averages per phase kind, to see where the time and money go. */
  statsByPhase(repo?: string): { phase: string; runs: number; avgMinutes: number; avgUsd: number; avgTurns: number; failed: number }[] {
    return this.db.prepare(
      `SELECT phase, COUNT(*) AS runs, ROUND(AVG(duration_ms) / 60000.0, 1) AS avgMinutes,
              ROUND(AVG(cost_usd), 2) AS avgUsd, ROUND(AVG(turns), 0) AS avgTurns,
              SUM(CASE WHEN outcome <> 'done' THEN 1 ELSE 0 END) AS failed
       FROM phases ${repo ? 'WHERE repo = ?' : ''} GROUP BY phase ORDER BY phase`,
    ).all(...(repo ? [repo] : [])) as unknown as { phase: string; runs: number; avgMinutes: number; avgUsd: number; avgTurns: number; failed: number }[]
  }

  /** Note (summary) of the most recent finished phase of a kind for an issue, if any. */
  lastPhaseNote(repo: string, issue: number, phase: string): string | null {
    const r = this.db.prepare(
      `SELECT j.note AS note FROM phases p JOIN jobs j ON j.id = p.job_id
       WHERE p.repo = ? AND p.issue = ? AND p.phase = ? ORDER BY p.id DESC LIMIT 1`,
    ).get(repo, issue, phase) as { note: string | null } | undefined
    return r?.note ?? null
  }

  /** Records that the worker already explained why it withholds approval for (issue, state). True if new. */
  markHold(repo: string, issue: number, state: string): boolean {
    const r = this.db.prepare(`INSERT OR IGNORE INTO holds (repo, issue, state, created_at) VALUES (?, ?, ?, ?)`)
      .run(repo, issue, state, new Date().toISOString())
    return r.changes > 0
  }

  /** Phases run since local midnight: count, dollars, minutes. */
  today(): { phases: number; usd: number; minutes: number } {
    const start = new Date(); start.setHours(0, 0, 0, 0)
    const r = this.db.prepare(
      `SELECT COUNT(*) AS phases, COALESCE(SUM(cost_usd), 0) AS usd, COALESCE(SUM(duration_ms), 0) / 60000 AS minutes FROM phases WHERE started_at >= ?`,
    ).get(start.toISOString()) as { phases: number; usd: number; minutes: number }
    return { phases: r.phases, usd: Math.round(r.usd * 100) / 100, minutes: Math.round(r.minutes) }
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
