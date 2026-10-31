# F10-T03 nested — Konsole Nimbus + apps por defecto

Fecha: 2026-10-31. Host Plasma 6.8.2 Wayland, Konsole 26.08.2.
Harness `tests/vm/nested-f10apps.sh` (igual que F10-T02).

## Ficheros

- `dotfiles/.config/konsolerc` — `[Desktop Entry] DefaultProfile=Nimbus.profile`.
- `dotfiles/.local/share/konsole/Nimbus.profile` — `[General]` Name/Parent
  (FALLBACK/), `[Appearance]` Font JetBrains Mono 12, ColorScheme Nimbus,
  AntiAliasFonts, BoldIntense, `[Scrolling]` HistorySize. Grupos exactos de
  `src/profile/Profile.cpp` upstream (ProfileWriter guarda Parent+Command en
  `[General]`, resto por grupos de `DefaultProperties`; el perfil vive en
  `GenericDataLocation/konsole/<nombre>.profile`).
- `dotfiles/.local/share/konsole/Nimbus.colorscheme` — esquema oscuro propio
  (sin activos Apple; tokens dark del contrato: bg #1C1C1E, acento #0A84FF).
  Formato exacto de `src/colorscheme/ColorScheme.cpp`: secciones
  `[Foreground]/[Background]/[Color0-7]/[ColorNIntense]` con `Color=R,G,B`;
  `[General]` Description + **Opacity=0.92 + Blur=true** (la opacidad y el
  blur viven en el esquema, NO en el perfil: el `DefaultProperties` del
  perfil no los contiene; `ColorScheme::read` lee `Opacity`/`Blur`).
- `dotfiles/.config/mimeapps.list` — defaults con `.desktop` presentes en el
  ISO (verificado en `/usr/share/applications`): http/https+html+pdf →
  firefox; jpg/png → gwenview; directorio → dolphin; mp4 → mpv.
  Sin cliente de correo instalado (sin thunderbird/kmail/kontact/merkuro) →
  sin default `mailto`; fallback documentado: webmail en Firefox.
  Sin visor PDF dedicado (sin okular/evince) → Firefox (declara
  `application/pdf`). Gwenview declara `image/*`; mpv declara `video/mp4`.

## Resultados

| Test | Resultado |
|---|---|
| `kreadconfig6` (HOME temporal): DefaultProfile=Nimbus.profile, ProfileFont=JetBrains Mono 12, ProfileScheme=Nimbus, SchemeOpacity=0.92, SchemeBlur=true, SchemeBg=28,28,30 | todos OK |
| `konsole --list-profiles` en nested | ofrece `Nimbus` |
| `spikes/nested/f10-konsole.png` (konsole --profile Nimbus) | SÍ: terminal oscuro con el perfil; 0 avisos "invalid color/opacity" en log (ColorScheme.cpp avisa si el scheme no parsea) |
| `xdg-mime query default` (https, html, pdf, jpeg, directory, mp4) | firefox, firefox, firefox, gwenview, dolphin, mpv (6/6) |
| JetBrains Mono instalada | sí (`fc-list`, 32 variantes) |
| Cleanup | 0 procesos resto, tmp borrado por trap |

## Límites

- Fuente renderizada exacta (JetBrains Mono 12) solo verificable a ojo en
  captura; el round-trip de config + ausencia de errores de parseo es la
  evidencia. Opacidad/blur dependen del compositor (KWin los aplica).
