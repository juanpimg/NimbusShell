# packages/dock — Dock macOS sobre Krema (R-DOCK)

Decisión F5-T02: **tema Nimbus sobre Krema 0.12.0 pinneado, sin fork**.
Krema (`https://github.com/isac322/krema`) es el dock layer-shell para
Plasma 6 (zoom parabólico, TaskManager, previews PipeWire, autohide,
pins). No se bifurca: se depende del paquete y se aporta `kremarc-nimbus`
([General] de `src/config/krema.kcfg`, fichero `~/.config/kremarc`).

- Licencia Krema: **GPL-3.0-or-later** (+ MIT-CMU en `LICENSES/`).
  Atribución en este README; sin activos propietarios.
- Build: AUR `krema` (`packaging/arch/PKGBUILD`); OBS `home:isac322/krema`
  (Debian/spec en `packaging/obs/`). Requisitos: Qt ≥6.8, KF6 ≥6.0,
  Plasma 6, `layer-shell-qt`, `plasma-workspace`, PipeWire.
- Tema claro/oscuro: sin clave en kcfg; hereda el color scheme de Plasma
  (Kirigami). Acrylic (3) = vidrio Tahoe sobre el scheme activo.
- Limitaciones: **sin papelera** (`ROADMAP.md`: trash pendiente);
  sin zoom dentro de panel (bug KDE 495100); `PinnedLaunchers` solo con
  IDs `.desktop` instalados; Krema no reserva papelera ni App menu.
- Ficheros: `kremarc-nimbus` (base), `kremarc-nimbus-autohide`
  (variante VisibilityMode=1 para la prueba F5-T03).
