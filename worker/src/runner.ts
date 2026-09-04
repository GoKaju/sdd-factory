import { spawn } from 'node:child_process'
import { createWriteStream, mkdirSync } from 'node:fs'
import { join } from 'node:path'
import { allowedToolsFor, skillFor, timeoutMinutes, type Phase } from './rules.ts'

export type RunOutcome = 'done' | 'failed' | 'timeout' | 'quota'

export interface RunResult {
  outcome: RunOutcome
  summary: string
  costUsd: number | null
  turns: number | null
}

export interface RunInput {
  phase: Phase
  issue: number
  cwd: string
  pluginDir: string
  note: string
  logPath: string
  runner: 'sdk' | 'cli'
  /** model for this phase, resolved by the worker from the repository's intelligence tier */
  model: string
}

const QUOTA = /spend limit|usage limit|rate limit|credit balance|quota/i

const prompt = (i: RunInput): string => `/${skillFor(i.phase)} ${i.issue}\n\n${i.note}`

/** Runs one phase headless and reports how it ended. Never throws. */
export const runPhase = async (i: RunInput): Promise<RunResult> => {
  mkdirSync(join(i.logPath, '..'), { recursive: true })
  const log = createWriteStream(i.logPath, { flags: 'a' })
  const write = (s: string): void => { log.write(s.endsWith('\n') ? s : `${s}\n`) }
  write(`# ${new Date().toISOString()} ${i.phase} #${i.issue} cwd=${i.cwd} runner=${i.runner}`)
  try {
    return i.runner === 'sdk' ? await runWithSdk(i, write) : await runWithCli(i, write)
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e)
    write(`# error: ${msg}`)
    return { outcome: QUOTA.test(msg) ? 'quota' : 'failed', summary: msg.slice(0, 2000), costUsd: null, turns: null }
  } finally {
    log.end()
  }
}

const runWithSdk = async (i: RunInput, write: (s: string) => void): Promise<RunResult> => {
  const { query } = await import('@anthropic-ai/claude-agent-sdk')
  const abort = new AbortController()
  const timer = setTimeout(() => abort.abort(), timeoutMinutes[i.phase] * 60_000)
  let summary = ''
  let costUsd: number | null = null
  let turns: number | null = null
  let outcome: RunOutcome = 'failed'
  let sawResult = false
  try {
    for await (const m of query({
      prompt: prompt(i),
      options: {
        cwd: i.cwd,
        plugins: [{ type: 'local', path: i.pluginDir }],
        model: i.model,
        settingSources: ['project'],
        permissionMode: 'acceptEdits',
        allowedTools: allowedToolsFor(i.phase),
        maxTurns: 200,
        abortController: abort,
      },
    })) {
      if (m.type === 'assistant') {
        for (const block of m.message.content) {
          if ('text' in block && typeof block.text === 'string') write(block.text)
          if ('name' in block && typeof block.name === 'string') write(`> tool ${block.name}`)
        }
      }
      if (m.type === 'result') {
        sawResult = true
        costUsd = 'total_cost_usd' in m && typeof m.total_cost_usd === 'number' ? m.total_cost_usd : null
        turns = 'num_turns' in m && typeof m.num_turns === 'number' ? m.num_turns : null
        if (m.subtype === 'success') {
          summary = m.result
          outcome = QUOTA.test(summary) ? 'quota' : 'done'
        } else {
          summary = `stopped: ${m.subtype}`
          outcome = 'failed'
        }
        write(`# result ${m.subtype} cost=${costUsd ?? '?'} turns=${turns ?? '?'}`)
      }
    }
  } catch (e: unknown) {
    if (abort.signal.aborted) return { outcome: 'timeout', summary: `timed out after ${timeoutMinutes[i.phase]} min`, costUsd, turns }
    throw e
  } finally {
    clearTimeout(timer)
  }
  if (!sawResult) {
    // The stream ended without a `result` message (SDK/CLI died mid-phase): never report success.
    return { outcome: 'failed', summary: 'the run ended without a result message (agent stream closed early)', costUsd, turns }
  }
  return { outcome, summary, costUsd, turns }
}

const runWithCli = (i: RunInput, write: (s: string) => void): Promise<RunResult> =>
  new Promise((resolve) => {
    const child = spawn('claude', [
      '--plugin-dir', i.pluginDir, '-p', prompt(i), '--model', i.model, '--max-turns', '200',
      '--permission-mode', 'acceptEdits', '--allowedTools', allowedToolsFor(i.phase).join(','),
      '--output-format', 'text',
    ], { cwd: i.cwd, stdio: ['ignore', 'pipe', 'pipe'] })
    let out = ''
    const timer = setTimeout(() => child.kill('SIGTERM'), timeoutMinutes[i.phase] * 60_000)
    child.stdout.on('data', (d: Buffer) => { const s = d.toString(); out += s; write(s) })
    child.stderr.on('data', (d: Buffer) => { const s = d.toString(); out += s; write(`! ${s}`) })
    child.on('close', (code, signal) => {
      clearTimeout(timer)
      const summary = out.slice(-2000)
      if (signal === 'SIGTERM') resolve({ outcome: 'timeout', summary, costUsd: null, turns: null })
      else if (QUOTA.test(out)) resolve({ outcome: 'quota', summary, costUsd: null, turns: null })
      else resolve({ outcome: code === 0 ? 'done' : 'failed', summary, costUsd: null, turns: null })
    })
  })
