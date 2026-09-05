import { createServer } from 'node:http'
import { timeoutMinutes, type Phase, type SddState } from '@sdd-factory/core'
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

const esc = (s: string): string => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c] ?? c)

const page = `<!doctype html><meta charset="utf-8"><title>sdd worker</title>
<style>body{font:14px system-ui;margin:24px;color:#222}h1{font-size:18px}table{border-collapse:collapse}td,th{padding:4px 10px;text-align:left;border-bottom:1px solid #eee}.pill{padding:2px 8px;border-radius:10px;background:#eef;font-size:12px}.warn{background:#fee}.ok{background:#efe}small{color:#666}</style>
<h1>sdd worker <small id="meta"></small></h1><div id="pause"></div>
<h2>Running</h2><table id="running"></table>
<h2>Waiting for a human</h2><table id="waiting"></table>
<h2>Open issues</h2><table id="issues"></table>
<h2>Time and cost per issue</h2><div id="ledger"></div>
<h2>Today</h2><div id="today"></div>
<script>
const f=async()=>{const s=await (await fetch('/status')).json();
document.getElementById('meta').textContent=' v'+s.version+' · '+s.repos.join(', ')+' · every '+s.intervalSeconds+'s · last tick '+(s.lastTickAt?new Date(s.lastTickAt).toLocaleTimeString():'—');
document.getElementById('pause').innerHTML=s.pausedUntil?'<p class="pill warn">paused until '+new Date(s.pausedUntil).toLocaleTimeString()+' — '+s.pauseReason+'</p>':'<p class="pill ok">active</p>';
const esc=t=>String(t).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));const row=(...c)=>'<tr>'+c.map(x=>'<td>'+x+'</td>').join('')+'</tr>';
document.getElementById('running').innerHTML=s.running.length?s.running.map(r=>row(r.repo+'#'+r.issue,r.phase,Math.round((Date.now()-Date.parse(r.startedAt))/60000)+' / '+r.budgetMinutes+' min')).join(''):row('<small>nothing running</small>');
const w=s.issues.filter(i=>i.waitingFor);document.getElementById('waiting').innerHTML=w.length?w.map(i=>row('<a href="'+i.url+'">#'+i.number+'</a> '+i.title,i.state,i.waitingFor)).join(''):row('<small>nothing</small>');
document.getElementById('issues').innerHTML=s.issues.map(i=>row('<a href="'+i.url+'">#'+i.number+'</a> '+i.title,i.type||'',i.size||'',i.state||'none')).join('');
document.getElementById('ledger').innerHTML=s.ledger.map(l=>'<details'+(l.open?' open':'')+'><summary><b>#'+l.issue+'</b> '+(l.title?esc(l.title):'')+' <span class="pill">'+(l.state||(l.open?'':'closed'))+'</span> · '+l.minutes.toFixed(1)+' min · $'+l.usd.toFixed(2)+'</summary><table><tr><th>Phase</th><th>Outcome</th><th>Tier</th><th>Started</th><th>Min</th><th>USD</th><th>Turns</th></tr>'+l.phases.map(p=>row(p.phase,'<span class="pill '+(p.outcome==='done'?'ok':'warn')+'">'+p.outcome+'</span>',(p.tier||'')+(p.tierReason?' <small>'+esc(p.tierReason)+'</small>':''),new Date(p.startedAt).toLocaleTimeString(),p.minutes.toFixed(1),p.usd==null?'—':p.usd.toFixed(2),p.turns==null?'—':p.turns)).join('')+'</table></details>').join('')||'<small>no phases yet</small>';
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
        // per-issue ledger: open issues first, then anything worked on in the last 7 days
        ledger: (() => {
          const seen = new Set<string>()
          const out: { repo: string; issue: number; title: string | null; state: string | null; open: boolean; minutes: number; usd: number; phases: ReturnType<JobStore['phasesOf']> }[] = []
          for (const i of state.issues) {
            const rows = store.phasesOf(i.repo, i.number); if (rows.length === 0) continue
            seen.add(`${i.repo}#${i.number}`)
            out.push({ repo: i.repo, issue: i.number, title: i.title, state: i.state, open: true, minutes: rows.reduce((a, r) => a + r.minutes, 0), usd: rows.reduce((a, r) => a + (r.usd ?? 0), 0), phases: rows })
          }
          for (const r of store.recentIssues(7)) {
            if (seen.has(`${r.repo}#${r.issue}`)) continue
            out.push({ repo: r.repo, issue: r.issue, title: null, state: null, open: false, minutes: r.minutes, usd: r.usd, phases: store.phasesOf(r.repo, r.issue) })
          }
          return out
        })(),
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
