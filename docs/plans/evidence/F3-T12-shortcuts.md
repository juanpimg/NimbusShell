# F3-T12 / F7-T10 — Atajos reales en el sistema instalado (2026-11-02)

## Evidencia

Sistema instalado out11, sesión `nimbus` (Plasma 6.8.2 Wayland), `ydotool`
por keycodes (sin depender del layout):

| Atajo | keycodes | Resultado | Captura |
| --- | --- | --- | --- |
| Meta+Espacio | `125:1 57:1 57:0 125:0` | Spotlight «Buscar en Spotlight» | `spikes/f2-install/37-out11-shortcut-spotlight.png` |
| Meta+W | `125:1 17:1 17:0 125:0` | Mission Control (4 Spaces, thumbs) | `spikes/f2-install/38-out11-shortcut-mission-control.png` |
| Meta+1 | `125:1 2:1 2:0 125:0` | Apps (40 apps, categorías) | `spikes/f2-install/39-out11-shortcut-apps.png` |

`Esc` cierra los overlays. Las capturas son de la sesión real, no del
harness.

## ydotoold de usuario (gap encontrado y corregido en repo)

`ydotoold` no traía unidad: al arrancarlo con `sudo` el socket quedaba
`root:root` y `ydotool` fallaba con `Permission denied`. Corregido con
`iso/profile/airootfs/etc/skel/.config/systemd/user/ydotoold.service`:

```ini
ExecStart=/usr/bin/ydotoold --socket-path=%t/.ydotool_socket --socket-perm=0600
WantedBy=plasma-workspace.target
```

Validado en la VM con un socket de usuario (`/run/user/1000/ydo2.sock`):
`srw------- nimbus nimbus` y Meta+Espacio abre Spotlight
(`docs/plans/evidence/F3-T12-ydotoold-user.png`). `nimbus-installed-setup`
lo enlaza en `plasma-workspace.target.wants`.

## Límites honestos

- `out11` no incluye aún esta unidad (se añadió después del build): el
  ydotoold de la prueba se arrancó a mano. Debe entrar en la próxima ISO.
- `shortcuts.real` del arnés sigue siendo un smoke test por hash de
  captura (no certifica la ventana objetivo); las capturas de esta ficha
  son la evidencia fuerte. F3-T12 (clics en menús, multi-monitor) y
  F7-T10 (matriz de 10 interacciones) siguen abiertos.
