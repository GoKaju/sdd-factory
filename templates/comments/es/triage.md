<!-- sdd:triage -->
<!-- Exactamente un comentario de triaje por Issue. Volver a ejecutar la fase de triage edita este comentario; nunca publica otro.
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
<!-- Todo lo que una fase posterior tendría que adivinar. Una casilla por pregunta; cada una lleva una respuesta propuesta
     que el autor puede confirmar con una palabra, y la fase que la adivinaría. Se marca al responderse y se registra en Aclaraciones. -->
- [ ] <pregunta> — **propuesta:** <valor por defecto de negocio> _(<spec | design | implement>)_
- [ ] <…>

### Aclaraciones
<!-- Respuestas del autor, una línea cada una, con sus palabras cuando son cortas. Son entradas de la spec: cada una se convierte
     en requisito, rechazo o criterio de aceptación, y la gate de completitud lo comprueba. Nunca se borran en ejecuciones posteriores. -->
- <pregunta> → <respuesta>

### Supuestos
<!-- Valores por defecto de negocio asumidos porque solo hay una lectura razonable; escritos aquí para que el autor pueda objetar antes de `sdd:ready`. -->
- <supuesto>

<!-- Cuando todas las casillas de Preguntas abiertas estén marcadas (o la lista esté vacía), el Issue está listo para el Gate 0. -->
