/** HTML markers of the single mechanical comments the factory keeps on an issue or PR. */
export const MARKERS = {
  triage: '<!-- sdd:triage -->',
  task: '<!-- sdd:task -->',
  ledger: '<!-- sdd:ledger -->',
  ledgerLine: '<!-- sdd:ledger-line -->',
} as const
export type Marker = keyof typeof MARKERS

/** Label that carries the workflow state; exclusive per issue. */
export const stateLabel = (state: string): string => `sdd:${state}`
export const LABEL_PREFIX = 'sdd:'
