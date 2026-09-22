<!-- sdd:task -->
<!-- Exactamente un comentario Task por Issue. En rework se edita este comentario; nunca se publica otro.
     Aprobación = estado `sdd:plan-approved` (humano), junto con la spec y el diseño. Avance = marcar las casillas.
     El Task es un plan de ejecución y nada más: el orden del trabajo. Toda decisión vive en el diseño;
     toda regla en la constitución; la definición de hecho en el skill de implementación. Si el plan
     necesita algo que el diseño no fija, primero se completa el diseño. -->

## Task — <título corto>

**Tipo de Issue:** Feature | Change | Bug | Task | Constitution
**Spec:** `docs/<dominio>/<módulo>/spec.md` → <MODULO>-001, <MODULO>-003
**Diseño:** `docs/<dominio>/<módulo>/design.md` (o "ninguno" en Issues Bug, Task y Constitution)

### Objetivo

<un párrafo: qué existirá cuando esto esté hecho, como resultado observable>

### Pasos

Ordenados para que cada paso deje el build en verde; cada paso nombra, con su nombre exacto, el elemento del diseño que realiza (una fila de Components, un Error o un Contract) y los requisitos que cubre.

- [ ] **T1** — <paso> (<elemento del diseño>; <MODULO>-NNN)
- [ ] **T2** — <paso>
- [ ] **T3** — <paso>
