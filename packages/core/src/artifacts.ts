/** True when a phase summary reports nothing a human should look at first. */
export const summaryClean = (summary: string | null | undefined): boolean =>
  !summary || !/NEEDS_HUMAN|BLOCKER|\bFAIL\b|pregunta(s)? abierta|open question|sin resolver|unresolved/i.test(summary)

/** The spec's "Open questions" section has no unchecked item and no placeholder. */
export const specClean = (spec: string): boolean => {
  const start = spec.search(/^## Open questions[^\n]*\n/m)
  if (start < 0) return true
  const rest = spec.slice(start).replace(/^[^\n]*\n/, '')
  const end = rest.search(/^## /m)
  const section = end < 0 ? rest : rest.slice(0, end)
  // TBD/TODO are placeholders only in upper case: "todo" is an ordinary Spanish word.
  return !/^- \[ \]/m.test(section) && !/\b(TBD|TODO)\b|\?\?\?/.test(section) && !/\bpor definir\b/i.test(section)
}

/** The design carries no decision still waiting for a human. */
export const designClean = (design: string): boolean =>
  !/NEEDS_HUMAN|pendiente de confirmaci[oó]n|pending human/i.test(design) && !/\b(TBD|TODO)\b/.test(design)
