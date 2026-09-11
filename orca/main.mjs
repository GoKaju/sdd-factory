// Orca plugin worker (plain Node, out of process). One command: read the local sdd worker's
// status page (http://127.0.0.1:4777/status, see worker/) and surface it as a notification.
// The worker itself is not started or controlled from here; Orca only observes it.
const STATUS_URL = process.env.SDD_WORKER_STATUS_URL ?? 'http://127.0.0.1:4777/status'

const summarize = (s) => {
  const running = (s.running ?? []).map((r) => `${r.repo.split('/')[1]}#${r.issue} ${r.phase}`)
  const waiting = (s.waiting ?? []).length
  const paused = s.pausedUntil ? ` · paused (${s.pauseReason ?? 'quota'})` : ''
  const today = s.today ? ` · today $${Number(s.today.usd ?? 0).toFixed(2)}` : ''
  const title = running.length ? `sdd worker: ${running.length} phase(s) running` : waiting ? `sdd worker: ${waiting} issue(s) wait for you` : 'sdd worker: idle'
  const body = [running.join(', '), waiting ? `${waiting} waiting for a human` : '', `v${s.version ?? '?'}${paused}${today}`].filter(Boolean).join('\n')
  return { title, body }
}

export default function activate(orca) {
  orca.commands.register('sdd-worker-status', async () => {
    let status
    try {
      const res = await fetch(STATUS_URL, { signal: AbortSignal.timeout(3000) })
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      status = await res.json()
    } catch (e) {
      const body = `No sdd worker answers at ${STATUS_URL}. Start it with \`pnpm start\` in worker/ (see README).`
      await orca.host.call('notifications.show', { title: 'sdd worker: not running', body })
      return { running: false, error: String(e) }
    }
    const { title, body } = summarize(status)
    await orca.host.call('notifications.show', { title, body: body.slice(0, 1000) })
    return { running: true, version: status.version, phases: status.running ?? [], waiting: status.waiting ?? [] }
  })
}
