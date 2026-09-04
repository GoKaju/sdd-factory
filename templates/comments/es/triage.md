<!-- sdd:triage -->
<!-- Exactamente un comentario de triaje por Issue. Volver a ejecutar /sdd-triage edita este comentario; nunca publica otro.
     El agente que lo escribe lee el repositorio pero no lo modifica.
     Aprobación de entrada (Gate 0) = un humano pone el estado `sdd:ready`. -->

## Triaje

**Tipo:** <Feature | Change | Bug | Task> <!-- "(cambiado desde Bug: la petición describe comportamiento nuevo)" cuando se retipa -->
**Tamaño:** <S | M | L> — <una frase que lo justifique>
**Esfuerzo:** <Low | Medium | High> sugerido en el campo `Effort` del Issue (pendiente de aceptación humana) · o «la organización no tiene campo Effort»
**Camino:** <Spec → Design → Task → Implementación → Revisión | Task → Implementación → Revisión>

### Completitud
- Problema: <presente | falta>
- Resultado esperado: <presente | vago: …>
- Ejemplos de comportamiento: <presentes | faltan>

### Duplicados y solapes
- <#123 "…" — se solapa en …> o "ninguno" (buscado en issues abiertos y cerrados, y en `docs/`)

### Especificaciones afectadas
| Dominio / módulo | Spec | Requisitos afectados |
| --- | --- | --- |
| <todos/tasks> | <existe · nueva> | <TSK-002, TSK-003 · ninguno todavía> |

### Preguntas abiertas
- [ ] <pregunta que el autor debe responder antes de que el Issue pueda pasar a `sdd:ready`>
- [ ] <…>

<!-- Cuando todas las casillas estén marcadas (o la lista esté vacía), el Issue está listo para el Gate 0. -->
