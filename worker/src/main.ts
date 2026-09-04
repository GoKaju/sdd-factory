import { join } from 'node:path'
import { loadConfig, type RepoConfig, type WorkerConfig } from './config.ts'
import { readFileSync } from 'node:fs'
import { comment, constitutionLanguage, isClosed, mergePr, openIssues, prBranch, setState, setWorking, upsertLedger, type OpenIssue } from './github.ts'
import { autoApproveFromConstitution, chooseTier, decide, sddConfigFromJson, summaryClean, tierFor, type Gate, type Phase, type RepoSddConfig, type SddState, type Tier } from './rules.ts'
import { runPhase } from './runner.ts'
import { JobStore } from './state.ts'
import { collectWorktrees, ensureWorktree, removeWorktree, worktreeNote } from './worktree.ts'
import { startStatusServer, waitingFor, type StatusState } from './status.ts'

interface Job { repo: RepoConfig; issue: OpenIssue; phases: Phase[]; reason: string }

const args = new Set(process.argv.slice(2))
const once = args.has('--once')
const dryRun = args.has('--dry-run')
const runner: 'sdk' | 'cli' = args.has('--cli') ? 'cli' : 'sdk'

const log = (s: string): void => { console.log(`${new Date().toISOString()} ${s}`) }

let pausedUntil = 0
let pauseReason = ''

const status: StatusState = {
  version: '', startedAt: new Date().toISOString(), intervalSeconds: 0, maxParallel: 0, repos: [],
  lastTickAt: null, pausedUntil: null, pauseReason: null, running: [], issues: [],
}
const publishPause = (): void => { status.pausedUntil = Date.now() < pausedUntil ? new Date(pausedUntil).toISOString() : null; status.pauseReason = status.pausedUntil ? pauseReason : null }

/** One tick: read GitHub, decide, run what fits in the parallel budget. */
const tick = async (cfg: WorkerConfig, store: JobStore): Promise<void> => {
  publishPause()
  if (Date.now() < pausedUntil) return // the pause was logged once when it started
  const jobs: Job[] = []
  const snapshot: StatusState['issues'] = []
  for (const repo of cfg.repos) {
    let issues: OpenIssue[]
    try { issues = await openIssues(repo.nameWithOwner, cfg.pluginDir, repo.path) }
    catch (e) { log(`! ${repo.nameWithOwner}: cannot list issues: ${String(e)}`); continue }
    const autoApprove = readAutoApprove(repo.path)
    try {
      const gone = await collectWorktrees(repo.path, new Set(issues.map((i) => i.number)))
      for (const n of gone) log(`gc ${repo.nameWithOwner}#${n}: worktree removed (issue closed)`)
    } catch (e) { log(`! ${repo.nameWithOwner}: worktree gc: ${String(e)}`) }
    for (const issue of issues) {
      snapshot.push({ repo: repo.nameWithOwner, number: issue.number, title: issue.title, type: issue.type, state: issue.state, size: issue.size, url: `https://github.com/${repo.nameWithOwner}/issues/${issue.number}`, waitingFor: waitingFor(issue, autoApprove) })
      const producing = producingPhase(issue.state)
      if (producing) issue.artifactClean = issue.artifactClean && summaryClean(store.lastPhaseNote(repo.nameWithOwner, issue.number, producing))
      const d = decide(issue, { autoSpec: repo.autoSpec, staleImplementingMinutes: cfg.staleImplementingMinutes, autoApprove })
      if (!d) {
        await explainWithheldApproval(store, repo, issue, autoApprove)
        continue
      }
      if (store.running(repo.nameWithOwner, issue.number)) continue
      if (d.approve || d.merge) {
        log(`plan ${repo.nameWithOwner}#${issue.number} [${issue.state}] → ${d.merge ? 'merge' : `approve ${d.approve}`} (${d.reason})`)
        if (dryRun) continue
        try {
          if (d.merge) { const pr = await mergePr(cfg.pluginDir, repo.path, issue.number); log(`  merged PR #${pr}`); await removeWorktree(repo.path, issue.number) }
          else await setState(cfg.pluginDir, repo.path, issue.number, d.approve)
          await comment(repo.nameWithOwner, issue.number, `**Worker sdd-factory:** ${d.merge ? 'PR mergeado' : `estado \`sdd:${d.approve}\``} por aprobación automática configurada en la constitución (${d.reason}).`)
        } catch (e) { log(`! ${repo.nameWithOwner}#${issue.number}: ${String(e)}`) }
        continue
      }
      if (store.alreadyTried(repo.nameWithOwner, issue.number, issue.state ?? 'none', issue.updatedAt)) continue
      jobs.push({ repo, issue, phases: d.phases, reason: d.reason })
    }
  }
  status.issues = snapshot
  status.lastTickAt = new Date().toISOString()
  if (jobs.length === 0) { log('nothing to do'); return }
  for (const j of jobs) log(`plan ${j.repo.nameWithOwner}#${j.issue.number} [${j.issue.state ?? 'none'}] → ${j.phases.join(' → ')} (${j.reason})`)
  if (dryRun) return
  const running: Promise<void>[] = []
  for (const j of jobs) {
    if (store.runningCount() + running.length >= cfg.maxParallel) break
    running.push(runJob(cfg, store, j))
  }
  await Promise.all(running)
}

const producingPhase = (state: SddState | null): Phase | null =>
  state === 'spec' ? 'spec' : state === 'design' ? 'design' : state === 'task' ? 'task' : null

const gateOf: Partial<Record<SddState, Gate>> = { spec: 'Spec', design: 'Design', task: 'Task' }

/**
 * A delegated gate that was NOT auto-approved gets exactly one comment per (issue, state) saying why,
 * persisted in the job store: the comment itself bumps the issue's updated_at, so the key must not
 * depend on it (that produced a comment loop in 0.3.7).
 */
const explainWithheldApproval = async (store: JobStore, repo: RepoConfig, issue: OpenIssue, autoApprove: ReadonlySet<Gate>): Promise<void> => {
  const gate = issue.state ? gateOf[issue.state] : undefined
  if (!gate || !autoApprove.has(gate) || issue.artifactClean || dryRun) return
  if (!store.markHold(repo.nameWithOwner, issue.number, issue.state ?? 'none')) return
  log(`hold ${repo.nameWithOwner}#${issue.number} [${issue.state}]: ${gate} delegated but the artifact is not clean; waiting for a human`)
  await comment(repo.nameWithOwner, issue.number,
    `**Worker sdd-factory:** el gate ${gate} está delegado en la constitución, pero no se aprueba automáticamente porque el artefacto no está limpio: quedan preguntas abiertas, marcas pendientes de confirmación humana, o la fase reportó BLOCKER/FAIL/NEEDS_HUMAN. Revisa y pon \`sdd:${issue.state}-approved\` a mano, o corrige y relanza la fase.`)
}

/** .sdd/config.json first; the old constitution line only as a fallback for repositories not yet migrated. */
/** Review cycles already published for the job's issue (0 when unknown). */
const reviewCyclesOf = (j: Job): number => j.issue.reviewCycles ?? 0

const readSddConfig = (repoPath: string): RepoSddConfig => {
  try { return sddConfigFromJson(readFileSync(join(repoPath, '.sdd', 'config.json'), 'utf8')) } catch { /* no config file */ }
  try { return { autoApprove: autoApproveFromConstitution(readFileSync(join(repoPath, 'docs', 'constitution.md'), 'utf8')), intelligence: {}, intelligenceMode: 'auto', maxReworkCycles: 3 } }
  catch { return { autoApprove: new Set(), intelligence: {}, intelligenceMode: 'auto', maxReworkCycles: 3 } }
}
/** Very short time-and-cost summary for the end of a PR description. */
export const ledgerMarkdown = (rows: { phase: string; runs: number; minutes: number; usd: number; tiers?: string | null }[], lang: 'es' | 'en'): string => {
  const t = lang === 'es'
    ? { title: 'Resumen SDD', phase: 'Fase', runs: 'Ejecuciones', tier: 'Nivel', min: 'Min', usd: 'USD', total: 'Total', by: 'generado por el worker sdd-factory' }
    : { title: 'SDD summary', phase: 'Phase', runs: 'Runs', tier: 'Tier', min: 'Min', usd: 'USD', total: 'Total', by: 'generated by the sdd-factory worker' }
  const tot = rows.reduce((a, r) => ({ minutes: a.minutes + r.minutes, usd: a.usd + r.usd }), { minutes: 0, usd: 0 })
  const lines = rows.map((r) => `| ${r.phase} | ${r.runs} | ${r.tiers ?? ''} | ${r.minutes.toFixed(1)} | ${r.usd.toFixed(2)} |`)
  return [`### ${t.title}`, '', `| ${t.phase} | ${t.runs} | ${t.tier} | ${t.min} | ${t.usd} |`, '| --- | ---: | --- | ---: | ---: |', ...lines,
    `| **${t.total}** | | | **${tot.minutes.toFixed(1)}** | **${tot.usd.toFixed(2)}** |`, '', `<sub>${t.by}</sub>`].join('\n')
}

/** One line for the PR: totals and a pointer to the issue's ledger comment. */
export const ledgerLine = (rows: { minutes: number; usd: number }[], lang: 'es' | 'en', repo: string, issue: number): string => {
  const m = rows.reduce((a, r) => a + r.minutes, 0).toFixed(0); const u = rows.reduce((a, r) => a + r.usd, 0).toFixed(2)
  return lang === 'es'
    ? `**SDD:** ${m} min · USD ${u} de agente hasta ahora · detalle por fase en el Issue #${issue} (https://github.com/${repo}/issues/${issue})`
    : `**SDD:** ${m} min · USD ${u} of agent time so far · per-phase detail on issue #${issue} (https://github.com/${repo}/issues/${issue})`
}

const readAutoApprove = (repoPath: string): Set<Gate> => readSddConfig(repoPath).autoApprove
const pluginVersion = (dir: string): string => { try { return (JSON.parse(readFileSync(join(dir, '.claude-plugin', 'plugin.json'), 'utf8')) as { version?: string }).version ?? '?' } catch { return '?' } }
const defaultTier = (phase: Phase): Tier => (phase === 'implement' || phase === 'spec' || phase === 'design' ? 'strong' : 'standard')

const runJob = async (cfg: WorkerConfig, store: JobStore, j: Job): Promise<void> => {
  const repo = j.repo.nameWithOwner
  const n = j.issue.number
  const stamp = new Date().toISOString().replace(/[:.]/g, '-')
  const logPath = join(cfg.home, 'logs', repo.replace('/', '-'), `${n}-${j.phases.join('+')}-${stamp}.log`)
  const id = store.start({ repo, issue: n, phases: j.phases.join('+'), stateAtStart: j.issue.state ?? 'none', issueUpdatedAt: j.issue.updatedAt, logPath })
  log(`start job ${id}: ${repo}#${n} ${j.phases.join(' → ')}`)
  await setWorking(cfg.pluginDir, j.repo.path, n, true)
  try {
    const branch = await prBranch(cfg.pluginDir, j.repo.path, n)
    const cwd = await ensureWorktree(j.repo.path, n, branch)
    for (const phase of j.phases) {
      const startedAt = new Date().toISOString()
      const sdd = readSddConfig(j.repo.path)
      const floor = tierFor(sdd.intelligence[phase], j.issue.size, defaultTier(phase))
      const { tier, reasons } = chooseTier(floor, sdd.intelligenceMode, phase, {
        rework: j.issue.state === 'rework' || reviewCyclesOf(j) > 0,
        reviewCycles: reviewCyclesOf(j),
        recentFailure: store.recentFailure(repo, phase),
      }, sdd.maxReworkCycles)
      status.running.push({ jobId: id, repo, issue: n, phase, startedAt })
      const r = await runPhase({ phase, issue: n, cwd, pluginDir: cfg.pluginDir, note: worktreeNote(n, branch, phase), logPath, runner, model: cfg.models[tier] })
      status.running = status.running.filter((x) => !(x.jobId === id && x.phase === phase))
      store.recordPhase({ jobId: id, repo, issue: n, phase, outcome: r.outcome, startedAt, costUsd: r.costUsd, turns: r.turns, tier, tierReason: reasons.join(', ') })
      store.setNote(id, `${phase}: ${r.summary.slice(0, 1500)}`)
      try {
        const lang = constitutionLanguage(j.repo.path); const rows = store.ledger(repo, n)
        await upsertLedger(repo, cfg.pluginDir, j.repo.path, n, ledgerMarkdown(rows, lang), ledgerLine(rows, lang, repo, n))
      } catch (e) { log(`! ledger ${repo}#${n}: ${String(e)}`) }
      log(`  ${phase}: ${r.outcome}${r.costUsd !== null ? ` $${r.costUsd.toFixed(2)}` : ''}${r.turns !== null ? ` ${r.turns} turns` : ''} [${tier}→${cfg.models[tier]}: ${reasons.join(', ')}]`)
      if (r.outcome !== 'done') {
        store.finish(id, r.outcome, `${phase}: ${r.summary.slice(0, 500)}`)
        if (r.outcome === 'quota') {
          // A monthly/org spend limit does not reset on its own: back off for hours, not minutes.
          const spendLimit = /spend limit/i.test(r.summary)
          const minutes = spendLimit ? Math.max(cfg.quotaPauseMinutes, 360) : cfg.quotaPauseMinutes
          pausedUntil = Date.now() + minutes * 60_000
          pauseReason = spendLimit ? 'org spend limit' : 'quota'
          publishPause()
          log(`${spendLimit ? 'org spend limit' : 'quota'} hit; pausing ${minutes} min (until ${new Date(pausedUntil).toISOString()})`)
        } else {
          await comment(repo, n, `**Worker sdd-factory:** la fase \`${phase}\` terminó con \`${r.outcome}\`. El estado del Issue no cambió; revisa el log \`${logPath}\` y corrige o relanza a mano.\n\n\`\`\`\n${r.summary.slice(-1200)}\n\`\`\``)
        }
        return
      }
    }
    store.finish(id, 'done')
    if (await isClosed(repo, n)) await removeWorktree(j.repo.path, n)
  } catch (e) {
    store.finish(id, 'failed', String(e).slice(0, 500))
    log(`! job ${id} failed: ${String(e)}`)
  } finally {
    await setWorking(cfg.pluginDir, j.repo.path, n, false)
  }
}

const printStats = (store: JobStore): void => {
  console.log('\nPor issue:')
  console.table(store.statsByIssue())
  console.log('Por fase:')
  console.table(store.statsByPhase())
}

const main = async (): Promise<void> => {
  const cfg = loadConfig()
  const store = new JobStore(cfg.home)
  if (args.has('--stats')) { printStats(store); return }
  log(`sdd worker: ${cfg.repos.map((r) => r.nameWithOwner).join(', ')} every ${cfg.intervalSeconds}s, maxParallel ${cfg.maxParallel}, runner ${runner}${dryRun ? ', dry-run' : ''}`)
  Object.assign(status, { version: pluginVersion(cfg.pluginDir), intervalSeconds: cfg.intervalSeconds, maxParallel: cfg.maxParallel, repos: cfg.repos.map((r) => r.nameWithOwner) })
  if (!once && cfg.statusPort > 0) startStatusServer(cfg.statusPort, status, store, log)
  if (once) { await tick(cfg, store); return }
  for (;;) {
    await tick(cfg, store)
    await new Promise((r) => setTimeout(r, cfg.intervalSeconds * 1000))
  }
}

main().catch((e) => { console.error(e); process.exit(1) })
