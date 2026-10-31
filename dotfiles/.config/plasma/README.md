# dotfiles — configs Plasma (perfil activo)

Dotfiles canónicos del perfil Plasma. Fuente de verdad que se genera hacia
NimbusOS en una sola dirección (NimbusShell → NimbusOS).

- `dotfiles/.config/plasma/`: configs base Plasma (`plasmarc`,
  `plasmashellrc`, `kwinrc`, `kdeglobals`, `kglobalshortcutsrc`, `krunnerrc`,
  `kscreenlockerrc`, `kwinrulesrc`, `plasma-org.kde.plasma.desktop-appletsrc`,
  `plasmanotifyrc` — F3-T09: banner arriba-derecha, 5s, DND).
- **Convención:** identificadores `org.nimbus.*` para plasmoids, efectos KWin
  y KCM propios.
- **Qué va:** solo configs del perfil Plasma. **Qué no:** nada del
  compositor/shell anterior (criterio F1-T04: cero menciones al perfil
  legacy en este árbol); el perfil anterior vive congelado bajo
  `legacy/` (ver su README).
