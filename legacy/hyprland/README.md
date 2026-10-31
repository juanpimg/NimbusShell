# Legacy Hyprland (congelado)

Estado final del perfil Hyprland+Quickshell (Hyprland, MacShell vendoreado,
kitty, gtk, qt6ct, `.local/bin`) tal como quedó en el tag `hyprland-final`.

- **Congelado:** no se mantiene ni se corrige aquí. Solo lectura y referencia
  (puertos de widgets/tokens hacia Plasma, tarea F10-T01).
- **No lo toca** el instalador en perfil Plasma (ver plan F1-T04).
- **Arrancar el perfil legacy:** `install.sh --profile=legacy-hypr`
  (disponible tras F1-T03; antes de eso, checkout del tag `hyprland-final`
  y `./install.sh` clásico).
- **Migración a Plasma:** `apps/nimbus-migrate/` (F9-T09); importa wallpaper,
  atajos, pins y ajustes donde sea posible, con dry-run y rollback.
