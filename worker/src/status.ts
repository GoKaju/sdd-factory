import { createServer } from 'node:http'
import { timeoutMinutes, type Phase, type SddState } from './rules.ts'
import type { OpenIssue } from './github.ts'
import type { JobStore } from './state.ts'

/** What a human would want to know at a glance; a view over the store, the tick snapshot and the log. */
export interface StatusIssue {
  repo: string
  number: number
  title: string
  type: string | null
  state: SddState | null
  size: string | null
  url: string
  /** the human action the issue waits for, if any */
  waitingFor: string | null
}

export interface RunningPhase { jobId: number; repo: string; issue: number; phase: Phase; startedAt: string }

export interface StatusState {
  version: string
  startedAt: string
  intervalSeconds: number
  maxParallel: number
  repos: string[]
  lastTickAt: string | null
  pausedUntil: string | null
  pauseReason: string | null
  running: RunningPhase[]
  issues: StatusIssue[]
}

/** Which human decision an issue in this state waits for (null when the orchestrator or nobody acts). */
export const waitingFor = (i: OpenIssue, autoApprove: ReadonlySet<string>): string | null => {
  switch (i.state) {
    case 'triage': return i.triageClean ? (autoApprove.has('Intake') ? null : 'set sdd:ready (Gate 0)') : 'answer the triage questions'
    case 'spec': return autoApprove.has('Spec') && i.artifactClean ? null : 'approve the spec (Gate 1)'
    case 'design': return autoApprove.has('Design') && i.artifactClean ? null : 'approve the design (Gate 2)'
    case 'task': return autoApprove.has('Task') && i.artifactClean ? null : 'approve the Task (Gate 3)'
    case 'final-review': return autoApprove.has('Final') && i.reviewPassed ? null : 'review and merge the PR (Gate 4)'
    default: return null
  }
}

const esc = (s: string): string => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c] ?? c)

const page = `<!doctype html><meta charset="utf-8"><title>sdd worker</title>
<style>body{font:14px system-ui;margin:24px;color:#222}h1{font-size:18px}table{border-collapse:collapse}td,th{padding:4px 10px;text-align:left;border-bottom:1px solid #eee}.pill{padding:2px 8px;border-radius:10px;background:#eef;font-size:12px}.warn{background:#fee}.ok{background:#efe}small{color:#666}</style>
<h1>sdd worker <small id="meta"></small></h1><div id="pause"></div>
<h2>Running</h2><table id="running"></table>
<h2>Waiting for a human</h2><table id="waiting"></table>
<h2>Open issues</h2><table id="issues"></table>
<h2>Today</h2><div id="today"></div>
<script>
const f=async()=>{const s=await (await fetch('/status')).json();
document.getElementById('meta').textContent=' v'+s.version+' · '+s.repos.join(', ')+' · every '+s.intervalSeconds+'s · last tick '+(s.lastTickAt?new Date(s.lastTickAt).toLocaleTimeString():'—');
document.getElementById('pause').innerHTML=s.pausedUntil?'<p class="pill warn">paused until '+new Date(s.pausedUntil).toLocaleTimeString()+' — '+s.pauseReason+'</p>':'<p class="pill ok">active</p>';
const row=(...c)=>'<tr>'+c.map(x=>'<td>'+x+'</td>').join('')+'</tr>';
document.getElementById('running').innerHTML=s.running.length?s.running.map(r=>row(r.repo+'#'+r.issue,r.phase,Math.round((Date.now()-Date.parse(r.startedAt))/60000)+' / '+r.budgetMinutes+' min')).join(''):row('<small>nothing running</small>');
const w=s.issues.filter(i=>i.waitingFor);document.getElementById('waiting').innerHTML=w.length?w.map(i=>row('<a href="'+i.url+'">#'+i.number+'</a> '+i.title,i.state,i.waitingFor)).join(''):row('<small>nothing</small>');
document.getElementById('issues').innerHTML=s.issues.map(i=>row('<a href="'+i.url+'">#'+i.number+'</a> '+i.title,i.type||'',i.size||'',i.state||'none')).join('');
document.getElementById('today').textContent=s.today.phases+' phases · $'+s.today.usd.toFixed(2)+' · '+s.today.minutes+' min';};
f();setInterval(f,10000);</script>`

/** Serves GET /status (JSON) and GET / (a small page) on 127.0.0.1:<port>. Read-only. */
export const startStatusServer = (port: number, state: StatusState, store: JobStore, log: (s: string) => void): void => {
  const server = createServer((req, res) => {
    if (req.url === '/status') {
      const body = {
        ...state,
        running: state.running.map((r) => ({ ...r, budgetMinutes: timeoutMinutes[r.phase] })),
        waiting: state.issues.filter((i) => i.waitingFor),
        today: store.today(),
      }
      res.writeHead(200, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' })
      res.end(JSON.stringify(body))
      return
    }
    if (req.url === '/' || req.url === '/index.html') {
      res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' }); res.end(page); return
    }
    res.writeHead(404); res.end(esc('not found'))
  })
  server.on('error', (e) => log(`! status server: ${String(e)}`))
  server.listen(port, '127.0.0.1', () => log(`status: http://127.0.0.1:${port}/`))
}
