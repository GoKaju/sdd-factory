import type { TierRule } from './intelligence.ts'
import { isGate, isTier, type Gate, type Phase, type Size, type Tier } from './types.ts'

/** Runtime policy of a repository (.sdd/config.json), the parts an orchestrator needs. */
export interface RepoSddConfig {
  autoApprove: Set<Gate>
  /** floors per phase (mode auto) or exact tiers (mode fixed) */
  intelligence: Partial<Record<Phase, TierRule>>
  intelligenceMode: 'auto' | 'fixed'
  maxReworkCycles: number
}

export const defaultRepoSddConfig = (): RepoSddConfig => ({ autoApprove: new Set(), intelligence: {}, intelligenceMode: 'auto', maxReworkCycles: 3 })

/** Parses .sdd/config.json; unknown gates and tiers are ignored (the config script validates them for humans). */
export const sddConfigFromJson = (json: string): RepoSddConfig => {
  const raw = JSON.parse(json) as { approvals?: { auto?: unknown }; intelligence?: Record<string, unknown>; review?: { maxReworkCycles?: unknown } }
  const auto = Array.isArray(raw.approvals?.auto) ? raw.approvals.auto : []
  const autoApprove = new Set<Gate>(auto.filter(isGate))
  const intelligence: RepoSddConfig['intelligence'] = {}
  for (const [k, v] of Object.entries(raw.intelligence ?? {})) {
    if (k.startsWith('$') || k === 'mode') continue
    if (isTier(v)) intelligence[k as Phase] = v
    else if (typeof v === 'object' && v !== null) {
      const rule: Partial<Record<Size | 'default', Tier>> = {}
      for (const key of ['S', 'M', 'L', 'default'] as const) { const t = (v as Record<string, unknown>)[key]; if (isTier(t)) rule[key] = t }
      intelligence[k as Phase] = rule
    }
  }
  const intelligenceMode = raw.intelligence?.mode === 'fixed' ? 'fixed' : 'auto'
  const mrc = raw.review?.maxReworkCycles
  return { autoApprove, intelligence, intelligenceMode, maxReworkCycles: typeof mrc === 'number' ? mrc : 3 }
}

/**
 * Parses `- **Auto-approved phase gates:** Intake, Task` (or the older `Auto-approved gates`) from the
 * constitution's Verification section. Only the five phase-gate names are recognised; the six Review
 * Gates (Spec Compliance, Design & Architecture, …) can never be delegated and are ignored here.
 * Legacy: repositories without .sdd/config.json.
 */
export const autoApproveFromConstitution = (constitution: string): Set<Gate> => {
  const m = /Auto-approved (?:phase )?gates:\*\*\s*([^\n]*)/i.exec(constitution)
  const out = new Set<Gate>()
  if (!m || !m[1]) return out
  for (const raw of m[1].split(/[,·;]/)) {
    const g = raw.trim().replace(/[`*]/g, '').replace(/\s*[—(-].*$/, '')
    // Exact match only: "Spec Compliance" or "Design & Architecture" are Review Gates, not phase gates.
    if (isGate(g)) out.add(g)
  }
  return out
}

/** The language of a constitution: `- **Language:** es` or `español/spanish` anywhere in the first lines. */
export const constitutionLanguage = (constitution: string): 'es' | 'en' =>
  /\*\*Language:\*\*\s*es\b/i.test(constitution) || /^-?\s*Language:\s*es\b/im.test(constitution) ? 'es' : 'en'
