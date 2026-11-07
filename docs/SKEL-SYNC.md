# Sincronización `dotfiles/` ↔ skel de NimbusOS

> **Estado 2026-11-07:** port aplicado en la rama `plasma-skel-sync` de
> NimbusOS (commit `917cc0f`). Quedan **9 extras legacy/ISO permitidos**; ya no
> hay ficheros de Plasma pendientes ni diferencias. La fuente de verdad sigue
> siendo `dotfiles/` de este repo y la dirección única **NimbusShell → NimbusOS**.

## Herramienta

```bash
scripts/nimbus-skel-sync --check   # faltantes/diferencias/extras no permitidos
scripts/nimbus-skel-sync --apply   # port aditivo; no borra legacy/ISO
```

El port es **aditivo** porque NimbusOS sigue usando Hyprland/MacShell en su
ISO actual: añade los dotfiles Plasma/Tahoe sin borrar `hypr/`, `macshell/`,
`Desktop/`, `.local/bin/`, etc. La allowlist está en el propio script.

## Comprobación manual

```bash
diff -rq dotfiles/ ../NimbusOS/nimbus-overlay/etc/skel/
```

## Divergencia actual (post-port)

Solo en `dotfiles/`: **ninguno** (62/62 ficheros 1:1).

Solo en el skel (legacy/ISO permitidos, no son divergencia de Plasma):

```
.config/gtk-3.0
.config/gtk-4.0
.config/hypr
.config/macdock
.config/macshell
.config/qt6ct
.config/quickshell
Desktop
.local/bin
```

Distinto: **ninguno** (incluido `kitty/kitty.conf`, que se actualizó con el
Ruling R20).

## Reglas del port

- **Se copia desde `dotfiles/`**, nunca al revés a mano.
- Los wrappers de `.local/bin` de la ISO (`macshell*`, `nimbus-*`) y el
  `Desktop/Instalar NimbusOS.desktop` son artefactos de la ISO: se preservan.
- `PlasmaUserFeedback` (telemetría desactivada, `FeedbackLevel=0`) **sí** viaja
  al skel.
- Tras el port, `diff -rq` debe quedar en cero salvo los artefactos de ISO
  declarados en esta página.

## Estado del port

- `scripts/nimbus-skel-sync --check` y `--apply` están cubiertos por
  `tests/install/test_skel_sync.sh` (13/13): copia, actualiza y preserva
  legacy/ISO, y falla ante extras no permitidos.
- **Aplicado** sobre la rama `plasma-skel-sync` de NimbusOS: 59 ficheros
  actualizados, `SKEL_SYNC_OK` y `build_iso.sh --check-only` → `CHECK-ONLY PASS`.
- La rama está **publicada** en `origin/plasma-skel-sync` (commit `917cc0f`)
  y es la base de `origin/plasma-migration` (commit `38318d7`):
  <https://github.com/juanpimg/NimbusOS/pull/new/plasma-migration>. Queda
  pendiente de revisión/merge; `main` de NimbusOS no se ha tocado.
- Los extras legacy/ISO que quedan son los de la allowlist
  (Hyprland/MacShell, `Desktop/`, `.local/bin/` y unidades de barra): son la
  parte que NimbusOS aún necesita para su ISO Hyprland.
