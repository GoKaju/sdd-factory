<!-- sdd:task -->
<!-- Exactamente un comentario Task por Issue. En rework se edita este comentario; nunca se publica otro.
     Aprobación = estado `sdd:task-approved` (humano). Avance = marcar las casillas.
     El Task es un plan de ejecución y nada más: el orden del trabajo. Toda decisión vive en el diseño;
     toda regla en la constitución; la definición de hecho en el skill de implementación. Si el diseño
     dejó abierto algo que el plan necesita, el Task no lo decide: el Issue vuelve a `design`. -->

## Task — <título corto>

**Tipo de Issue:** Feature | Change | Bug | Task | Constitution
**Spec:** `docs/<dominio>/<módulo>/spec.md` → <MODULO>-001, <MODULO>-003
**Diseño:** `docs/<dominio>/<módulo>/design.md` (o "ninguno" en Issues de tipo Task)
**Constitución:** v<x.y.z>

### Objetivo

<un párrafo: qué existirá cuando esto esté hecho, como resultado observable>

### Pasos

Ordenados para que cada paso deje el build en verde; cada paso nombra el elemento del diseño que realiza y los requisitos que cubre.

- [ ] **T1** — <paso> (<elemento del diseño>; <MODULO>-NNN)
- [ ] **T2** — <paso>
- [ ] **T3** — <paso>
