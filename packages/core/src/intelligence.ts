import { TIERS, type Phase, type Size, type Tier } from './types.ts'

/** A phase's intelligence: one tier, or a tier per triage size with a default. */
export type TierRule = Tier | Partial<Record<Size | 'default', Tier>>

/** Automatic raises stop at `strong`; `frontier` is reached only by an explicit floor (cost). */
export const raise = (t: Tier, steps = 1): Tier => (t === 'frontier' ? t : TIERS[Math.min(TIERS.indexOf(t) + steps, TIERS.indexOf('strong'))] as Tier)

export interface TierSignals {
  /** the issue is in `rework`, or the phase runs after a failed review cycle */
  rework: boolean
  /** review cycles already published on the PR */
  reviewCycles: number
  /** the last run of this phase in this repo failed or timed out (quota excluded) */
  recentFailure: boolean
}

/**
 * Chooses the tier for a phase: the floor from the config, raised by what the orchestrator knows.
 * Never below the floor. Returns the tier and the rules that fired, for the ledger and the log.
 */
export const chooseTier = (floor: Tier, mode: 'auto' | 'fixed', phase: Phase, sig: TierSignals, maxReworkCycles: number): { tier: Tier; reasons: string[] } => {
  if (mode === 'fixed') return { tier: floor, reasons: ['fixed'] }
  let tier = floor; const reasons: string[] = [`floor ${floor}`]
  if (sig.rework && (phase === 'implement' || phase === 'review')) { tier = raise(tier); reasons.push('+1 rework') }
  if (phase === 'review' && sig.reviewCycles + 1 >= maxReworkCycles && tier !== 'frontier') { tier = 'strong'; reasons.push('last permitted cycle → strong') }
  if (sig.recentFailure) { tier = raise(tier); reasons.push('+1 recent failure of this phase') }
  return { tier, reasons }
}

/** Resolves a phase's tier for an issue of the given triage size (unknown size → default). */
export const tierFor = (rule: TierRule | undefined, size: Size | null, fallback: Tier): Tier => {
  if (rule === undefined) return fallback
  if (typeof rule === 'string') return rule
  return (size ? rule[size] : undefined) ?? rule.default ?? fallback
}

/** Floor used when the repository's config says nothing about a phase. */
export const defaultTier = (phase: Phase): Tier => (phase === 'implement' || phase === 'spec' || phase === 'design' ? 'strong' : 'standard')
