# dotfiles — configs Plasma (perfil activo)

Dotfiles canónicos del perfil Plasma. Fuente de verdad que se genera hacia
NimbusOS en una sola dirección (NimbusShell → NimbusOS).

- `dotfiles/.config/plasma/`: configs base Plasma (`plasmarc`,
  `plasmashellrc`, `kwinrc`, `kdeglobals`, `kglobalshortcutsrc`, `krunnerrc`,
  `kscreenlockerrc`, `kwinrulesrc`, `plasma-org.kde.plasma.desktop-appletsrc`).
- **Convención:** identificadores `org.nimbus.*` para plasmoids, efectos KWin
  y KCM propios.
- **Qué va:** solo configs del perfil Plasma. **Qué no:** nada de
  `hyprland`/`quickshell` (`grep -r hyprland` debe dar vacío, F1-T04);
  el perfil antiguo vive en `legacy/hyprland/dotfiles/`.
