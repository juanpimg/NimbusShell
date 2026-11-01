# F11-T06 (ayuda offline + docs) — evidencia nested

## Qué
`apps/nimbus-help/` (Qt6 Quick, CMake, sin KF): visor offline de
`docs/user-guide/README.md` + `shortcuts.md` vía `Text.MarkdownText`
(títulos, listas, tablas, enlaces; sin HTML/JS), pestañas Guía/Atajos,
selector ES/EN, búsqueda incremental (cuenta + filtra líneas),
`--tab guide|shortcuts` (`about` = alias de guide; dos binarios
separados, no uno solo). Lee `/usr/share/nimbus/user-guide/`
(instalado por su CMakeLists) con fallback `NIMBUS_GUIDE_DIR`/repo.
`.desktop` (System/Help) + `assets/nimbus-help.svg` propio.
`docs/user/README.md` (índice es → guía/atajos/en) +
`docs/user/en/README.md` (resumen EN breve). Menú N: «Ayuda de Nimbus»
→ `cmd: "nimbus-help"`.

## Prueba
Mismo `tests/vm/nested-about.sh` (RC=0): `help VIVO`, `SHOT_OK`,
`f10-help.png` + `f10-help-grab.png` (720x520: pestañas Guía/Atajos
completas, tabla de atajos en fondo oscuro legible, ruta de docs
visible). `0 errores QML`. Fix aplicado tras 1ª pasada: TextArea sin
fondo heredaba blanco (texto invisible) → `background` oscuro del
contrato §2; TabBar con anchos explícitos (antes «Ata…» truncado).
`qmllint` limpio; `bash -n` harness OK.

## Límites
- EN muestra índice/resumen (la guía completa solo existe en ES):
  documentado en el propio visor, no inventado.
- Búsqueda = filtrado por líneas, sin salto al siguiente ni resaltado.
- Sin test de clics de idioma/búsqueda en nested (solo render inicial).
