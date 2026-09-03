import { readFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { join } from 'node:path'

export interface RepoConfig {
  nameWithOwner: string
  path: string
  autoSpec: boolean
}

export interface WorkerConfig {
  intervalSeconds: number
  maxParallel: number
  pluginDir: string
  quotaPauseMinutes: number
  staleImplementingMinutes: number
  repos: RepoConfig[]
  home: string
}

export const workerHome = (): string => process.env.SDD_WORKER_HOME ?? join(homedir(), '.sdd', 'worker')

export const loadConfig = (file = join(workerHome(), 'config.json')): WorkerConfig => {
  const raw: unknown = JSON.parse(readFileSync(file, 'utf8'))
  if (typeof raw !== 'object' || raw === null) throw new Error(`invalid config: ${file}`)
  const c = raw as Partial<WorkerConfig> & { repos?: Partial<RepoConfig>[] }
  const repos = (c.repos ?? []).map((r) => {
    if (!r.nameWithOwner || !r.path) throw new Error('each repo needs nameWithOwner and path')
    return { nameWithOwner: r.nameWithOwner, path: r.path, autoSpec: r.autoSpec ?? false }
  })
  if (repos.length === 0) throw new Error('config.repos is empty')
  if (!c.pluginDir) throw new Error('config.pluginDir is required')
  return {
    intervalSeconds: c.intervalSeconds ?? 60,
    maxParallel: c.maxParallel ?? 1,
    pluginDir: c.pluginDir,
    quotaPauseMinutes: c.quotaPauseMinutes ?? 30,
    staleImplementingMinutes: c.staleImplementingMinutes ?? 45,
    repos,
    home: workerHome(),
  }
}
