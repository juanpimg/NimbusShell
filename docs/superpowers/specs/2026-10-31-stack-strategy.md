# Estrategia de stack NimbusOS/NimbusShell — 2026-10-31

## 1. Punto de partida real (no lo que parece)

- **NimbusOS ya está basado en CachyOS.** `build_iso.sh` usa el perfil
  `CachyOS-Live-ISO` pineado + Calamares + overlay propio.
- **El compositor es Hyprland** (Wayland, CSD-only), no CachyOS. CachyOS es
  la base de paquetes/kernel/ISO; Hyprland es quien dibuja ventanas.
- **La capa propia es MacShell** (Quickshell/QML) + configs Lua + hyprbars.
  No hay fork del compositor ni del shell upstream: hay una capa de
  integración y parches documentados (`NimbusOS Ruling`).
- Estado técnico: semáforos nativos hyprbars, zoom flotante macOS, drag con
  offset, Mission Control/Spotlight/Dock aproximados. El 80% está; el 20%
  restante es la asíntota (píxel, CSD, menús globales, oclusión, ABI).

## 2. Diagnóstico: no estáis estancados por el compositor

El cuello de botella no es "Hyprland vs Plasma" sino:

1. **La asíntota del 1:1.** Cada píxel cuesta más que el anterior; sin un
   contrato de "qué es 1:1", el trabajo no termina nunca.
2. **La integración con Hyprland es un blanco móvil.** 0.57 (28-oct-2026)
   elimina el config `.conf` legacy (solo Lua), los plugins rompen ABI por
   release (hyprpm pinnea), y las capas `top` cambian de orden bajo
   fullscreen. Mantener "latest" es deuda permanente.
3. **El techo estructural de cada stack es similar.** Ninguno da menú
   global GTK en Wayland (falta protocolo) ni controla CSD/libadwaita.
   Cambiar de compositor no elimina ese techo.

## 3. Opciones evaluadas

| Opción | 1:1 alcanzable | Estabilidad | Esfuerzo | Mantenimiento | Veredicto |
|---|---|---|---|---|---|
| **A. Hyprland + MacShell (actual)** | 80–90% con control total del píxel; techo en CSD/menú GTK | Media: ABI plugins, config Lua cambiante | Alto para el último 10% | Alto (rolling + hyprbars) | **Mantener a corto plazo**, congelar versión y aislar integración |
| **B. Plasma 6 / KWin + tema Nimbus** | 80% con menos código: SSD real (Klassy/Aurorae), KRunner, panel; techo en menú GTK Wayland, Activities≠Spaces, Latte muerto | Alta: APIs KDecoration estables, releases semestrales | Medio para el 80%, alto para el 20% | Bajo/medio | **Plan B serio**: prototipo time-boxed |
| **C. GNOME/Mutter + extensiones** | 70–80%: dock/overview/a11y maduros; extensiones frágiles, CSD | Media | Medio | Medio | No como base principal |
| **D. COSMIC (Rust/Smithay)** | Bajo hoy: pre-1.0, ecosistema pequeño | Media/baja | Alto (Rust/iced) | Medio | Vigilar, no adoptar |
| **E. Wayfire/Niri/Sway** | Menor: sin SSD (Niri/Sway), decoraciones Wayfire degradadas | Alta (Sway/Niri) | Alto | Bajo | No para 1:1 |
| **F. Compositor propio desde cero** | Potencial 100% | — | **6–10 personas-año** (24–36 p-m solo compositor usable) | Enorme | **No viable** para 1–2 personas + IA |
| **G. Híbrido: edición Hyprland + edición Plasma** | Dos techos, una marca | Alta en Plasma, media en Hyprland | Duplica testing | Medio | Viable tras el gate de Fase 1 |

## 4. Recomendación (orden de prioridad)

1. **No escribir un compositor.** No es un problema de talento; es un
   problema de años y de protocols/drivers. La IA acelera QML/boilerplate,
   no depura races de Wayland ni NVIDIA.
2. **Mantener Hyprland como edición insignia los próximos 6 meses**, pero:
   - **Pinnear** Hyprland + hyprbars (hyprpm/flake) y probar cada bump en VM.
   - **Migrar ya a Lua-only** (0.57 elimina `.conf`); el `.conf` actual es
     deuda que caduca.
   - **Aislar la integración** en una capa `Nimbus Integration API`
     (acciones de ventana, geometría, workspaces, foco) para que el QML no
     llame `hl.dsp.*`/`hyprctl` directamente. Es el refactor de mayor
     retorno: permite un backend KWin/Plasma futuro sin reescribir MacShell.
3. **Prototipo Plasma 6 time-boxed (2–3 semanas) en paralelo**, misma marca:
   Klassy/Kvantum/WhiteSur + panel/dock + KRunner/Activities + atajos.
   Medir los 10 workflows must-have, no la estética global.
4. **Base de distro: seguir en CachyOS** (ya está, funciona). No cambiar a
   Arch vanilla ahora: no resuelve el 1:1 y añade trabajo de ISO. CachyOS
   solo acopla cadencia; mitigar pineando el perfil y evitando branding
   ajeno. Revisar en 1.0 si el mantenimiento duele.
5. **Solo si el gate lo pide**: plugin fino de Hyprland (no fork) para el
   10% que falta, y propuesta upstream. Nunca fork de KWin ni compositor
   propio.

## 5. Plan por fases (con gates)

### Fase 0 — Contrato Tahoe (1 semana)
- Lista cerrada de must-have: Spaces, Mission Control, Spotlight,
  Launchpad, Dock, menú global, semáforos (activa/inactiva/hover),
  zoom/fullscreen, atajos universales, multi-monitor, accesibilidad.
- Cada uno con test de aceptación en VM (captura + interacción).
- Salida: `docs/specs/tahoe-contract.md`. Sin esto, el 1:1 es infinito.

### Fase 1 — Estabilizar Hyprland + prototipo Plasma (2–3 semanas)
- Hyprland: pin, Lua-only, capa de integración, CI de arranque en VM.
- Plasma: VM con CachyOS/Arch + Plasma 6 + Klassy/Kvantum + panel/dock +
  KRunner/Activities; implementar los mismos 10 workflows.
- Medir por workflow: tiempo, LOC, estabilidad, RAM, arranque.

### Fase 2 — Gate de decisión (1 semana)
- Scorecard: ¿cuántos must-have logra cada stack? ¿coste del 20% restante?
  ¿mantenimiento anual? Decisión documentada como Ruling.
- Escenarios:
  - Plasma ≥80% must-have con menos código → **Plasma default**,
    Hyprland edición "Pro".
  - Hyprland mantiene ventaja clara → **Hyprland default**, Plasma como
    edición estable opcional.
  - Empate → híbrido (G) con una sola capa de marca.

### Fase 3 — Consolidar (4–6 semanas)
- Portar shell/marca/settings al stack elegido, ISO, tests, docs.
- Retirar la deuda del stack no elegido (o congelarlo como edición).

### Fase 4 — Último 10% (continuo)
- Plugin fino/upstream PR para lo que falte; nunca reescribir el
  compositor.

## 6. Riesgos y mitigaciones

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Hyprland 0.57 elimina `.conf` | Sesión rota al actualizar | Migrar a Lua-only ya; CI de arranque |
| ABI de hyprbars rompe | Sin semáforos tras update | Pin hyprpm + ventana de prueba; capa propia |
| Quickshell API churn | Shell no carga | Pin versión; tests de carga |
| CachyOS cadence | ISO retrasada | Pin del perfil; repo propio mínimo |
| Burnout 1 maintainer | Proyecto parado | Fase 0/2 acotan alcance; no forkear |
| Menú global GTK Wayland | 1:1 imposible hoy | Aceptar límite o propuesta upstream; no bloquea |

## 7. Lo que NO hacer

- Compositor propio (6–10 personas-año).
- Fork de KWin o de Plasma.
- Reescribir MacShell desde cero.
- Perseguir píxeles sin contrato de aceptación.
- Cambiar la base de distro ahora.
- Seguir `latest` de Hyprland sin pin.

## 8. Decisión abierta (la que cambia el default)

¿NimbusOS a 12 meses es **tu escritorio personal** (prioridad: control y
experimentación → Hyprland) o **una distro que otros instalan** (prioridad:
estabilidad y soporte → Plasma como default)? El plan es el mismo; cambia
el stack por defecto y el coste de mantenimiento.
