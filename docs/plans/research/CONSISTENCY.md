# Consistencia plan Plasma vs briefs (2026-10-31, reviewer, sin código)

Fuentes: plan `docs/superpowers/plans/2026-10-31-plasma-migration.md`, spec diseño/stack, briefs F2,F3,F4,F6-F7,F8,F9,F10,F11,F12.

| ID | Sev | Briefs | Finding | Fix exacto |
|---|---|---|---|---|
| C01 | alta | plan F5 vs (sin brief F5) | 12 tareas Dock sin brief; fork-vs-theme Krema indeciso (F0-T03/F5-T01) | Crear `F5-dock.md` antes de F5; congelar fork|dep|theme en F0-T03 con Ruling |
| C02 | alta | F2 vs F3/F4 | Klassy 6.7.3 (para Plasma ≥6.6.1) vs pin Plasma 6.8.2; compatibilidad no probada | F2-T01: matriz Plasma×Klassy en VM + fallback R-KLASSY (klassy-bin OBS o KDecoration custom) |
| C03 | alta | F2 vs F9/F10/plan F2-T02 | F2 introduce `plasma-login-manager` 6.8.2 sin tarea; plan dice SDDM\|greetd; F9/F10 asumen SDDM | F2-T02: spike SDDM vs plasma-login-manager + Ruling 1 línea; alinear F9/F10 al ganador |
| C04 | alta | F9 vs F10/F11 | i18n: F9 `I18n.js`+`es.json` vs F10/F11 ki18n/`qsTr`+`.ts` ("NO es.js") | Fijar ki18n/.ts; F9 usa `I18n.js` solo como fuente de cadenas a portar |
| C05 | media | F3 vs F4 | `klassyrc`: F3 `~/.config/klassyrc` vs F4 `~/.config/klassy/klassyrc` | F3-T02: exportar preset con `klassy-settings`, fijar ruta real en ambos briefs |
| C06 | media | F8 vs plan F8 | Gate "5 páginas" vs brief "7 páginas" vs T02–T07 = 6 contenidos | Congelar 6 páginas + reset; corregir gate y matriz 1:1 a "6 páginas" |
| C07 | media | F2 vs F9 | Calamares: F2 `[..,displaymanager,packages,fstab,grub,..]+netinstall` vs F9 `[..,summary,install,removeuser]` | Unificar en `settings.conf` de F2; documentar `removeuser`/netinstall como módulos, no pasos distintos |
| C08 | media | F2-T04 (R-APPLE) | WhiteSur "GPL con atribución" sin auditoría de assets Apple | F2-T04: `grep` binarios/png/svg + `ATTRIBUTION.md`; prohibir redistribuir si trae assets Apple; usar solo presets propios |
| C09 | media | F6-F7 vs plan | Spaces "por monitor" imposible (Plasma: escritorios globales); matriz 1:1 no registra divergencia | Añadir Ruling R-SPACES (global, documentado) + accept F7-T01/T08 |
| C10 | media | F6-F7 vs F6-T01/T08 | KRunner "fullscreen skin" sin API oficial (overlay propio); runner Python vs <50 ms/10k archivos | F0-T04 decide overlay-vs-popup + benchmark; F6-T02 escala a C++ solo si Python falla |
| C11 | baja | F4 vs F6 | `Meta+F`/`Meta+Espacio` sin tabla de colisiones; editar `kglobalshortcutsrc` a mano | F4-T08: tabla colisiones + aplicar vía `kglobalaccel setShortcut`, no solo fichero |
| C12 | baja | F11 vs spec | "Better Blur/Glass": taj-ny abandonado vs xarblu/4v3ngR sin pin; nombre ambiguo | F11-T02: pin commit + tiers alto/bajo + fallback blur stock; prohibir `latest` |

Rulings: R-GTK/R-DOCK/R-CTRL/R-PARALLEL respetados. Gaps: R-APPLE (C08), R-KLASSY (C02), R-CACHYOS (pin snapshot pendiente F2-T01), R-ISO (netinstall→Full ok, C07).
Omitidos: kwallet-PAM roto con greetd (solo F2 lo cita); plantilla `flatpak override` sin dueño; KAuth `.policy` solo en F8; Secure Boot/MOK solo F12; `Accessible.*` obligatorio en QML custom (F11 lo cita, F3/F6 no); clave telemetría inestable 6.6→6.8 (F2 lo admite, F12 la exige OFF).
Tareas sin brief: F0 (spikes), F1 (repo), F5 (Dock), F13 (upstream). Briefs sin tarea: ninguno.

**Veredicto: NO-GO condicional** — crear brief F5 y resolver C02–C04 + R-SPACES antes de F2-T01; resto entra como Rulings en sus tareas.
