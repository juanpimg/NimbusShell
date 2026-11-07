# Sincronización `dotfiles/` ↔ skel de NimbusOS

> **Estado 2026-11-07:** divergencia **conocida y pendiente** (29 entradas).
> La fuente de verdad es `dotfiles/` de este repo; el skel de NimbusOS todavía
> contiene el perfil Hyprland congelado. No se copia a mano: el port se hace en
> una sola dirección **NimbusShell → NimbusOS**.

## Comprobación

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

## Pendiente

El port del skel se hace en el repo NimbusOS (F12-T03, ISO Full). Hasta
entonces, este repo documenta la divergencia aquí y `AGENTS.md` apunta a este
documento en vez de a las Rulings R1–R5 del README antiguo.
