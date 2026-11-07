# Sincronización `dotfiles/` ↔ skel de NimbusOS

> **Estado 2026-11-07:** divergencia **conocida y pendiente** (29 entradas).
> La fuente de verdad es `dotfiles/` de este repo; el skel de NimbusOS todavía
> contiene el perfil Hyprland congelado. No se copia a mano: el port se hace en
> una sola dirección **NimbusShell → NimbusOS**.

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

## Divergencia actual

Solo en `dotfiles/` (configs Plasma/Tahoe que el skel aún no tiene):

```
.config/autostart
.config/discover-notifierrc
.config/discoverrc
.config/dolphinrc
.config/environment.d
.config/kaccessrc
.config/kdeglobals
.config/kglobalshortcutsrc
.config/klassy
.config/konsolerc
.config/kwinrc
.config/kwinrulesrc
.config/mimeapps.list
.config/nimbus-bar
.config/plasma
.config/PlasmaUserFeedback
.config/sddm
.config/systemd
.local/share
```

Solo en el skel (restos del perfil Hyprland congelado):

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

Distinto:

```
.config/kitty/kitty.conf
```

## Reglas del port

- **Se copia desde `dotfiles/`**, nunca al revés a mano.
- Los wrappers de `.local/bin` de la ISO (`macshell*`, `nimbus-*`) y el
  `Desktop/Instalar NimbusOS.desktop` son artefactos de la ISO: se excluyen del
  skel del escritorio o se justifican con una Ruling de una línea.
- `PlasmaUserFeedback` (telemetría desactivada, `FeedbackLevel=0`) **sí** debe
  viajar al skel.
- Tras el port, `diff -rq` debe quedar en cero salvo los artefactos de ISO
  declarados en esta página.

## Estado del port

- `scripts/nimbus-skel-sync --check` y `--apply` están cubiertos por
  `tests/install/test_skel_sync.sh` (13/13): copia, actualiza y preserva
  legacy/ISO, y falla ante extras no permitidos.
- El `--apply` real se ejecuta sobre una rama de NimbusOS
  (`plasma-skel-sync`) y se valida con `--check` antes de commitear; no se
  empuja sin revisión.
- Los extras legacy/ISO que quedan tras el port son los de la allowlist
  (Hyprland/MacShell, `Desktop/`, `.local/bin/` y unidades de barra). No son
  divergencia de Plasma: son la parte que NimbusOS aún necesita para su ISO
  Hyprland.
