# Evaluación: `vercel-labs/agent-desktop` (2026-11-02)

## Veredicto

**No se integra** en NimbusShell ni en el workflow dev-vm. Es útil solo como
inspector manual del árbol de accesibilidad de apps Qt/X11 (p. ej. Dolphin),
no para las superficies QML/layer-shell de la barra, CC, menú o Dock.

## Qué es

- CLI + librería nativa en Rust (Apache-2.0, `agent-desktop@1.0.2`), publicada
  en npm con binario ELF x86_64 (~29 MB). Node ≥18 solo para el launcher.
- Lee **AT-SPI** (accesibilidad), no píxeles; `snapshot` → `click @s:eN`.
- Requiere sesión gráfica y `at-spi2-core`; se ejecuta **dentro** del guest
  (bus de sesión + `XDG_RUNTIME_DIR`). No habla VNC ni HMP.
- En Wayland: sin control de ventanas (`focus-window`/`close-app` no
  soportados), sin puntero físico fiable y `screenshot` vía portal con
  consentimiento humano. Soporte validado en GNOME/Ubuntu, no Plasma.

## Prueba real (host, sin tocar out15)

Instalación temporal sin root:

```bash
npm install --prefix /tmp/opencode/ad-prefix agent-desktop@1.0.2
/tmp/opencode/ad-prefix/node_modules/.bin/agent-desktop version  # 1.0.2 linux/x86_64
agent-desktop status    # accessibility: granted
agent-desktop list-apps # 22 apps
agent-desktop snapshot --app dolphin  # 123 refs, complete:true
```

`click` sobre un `option` → `POLICY_DENIED`; sobre un `tab` → `ACTION_FAILED`;
`close-app` → `ACTION_NOT_SUPPORTED` (Wayland). Dolphin se cerró y
`~/.agent-desktop` se borró tras la prueba.

## Por qué no sirve para NimbusShell

- `plasmashell`/QML exponen un árbol AT-SPI inútil (`textfield`, `scrollbar`);
  no hay refs de nuestras cápsulas, sliders ni ventanas layer-shell.
- La evidencia visual sigue siendo QEMU `screendump` + `spectacle`; el input,
  HMP/`ydotool` + KWin scripting.
- Añadiría una dependencia npm/nativa y superficie de supply-chain
  (`postinstall` descarga un binario) sin resolver ningún gap del proyecto.

## Si se quiere usar puntualmente

Solo para depurar widgets Qt dentro del guest, por SSH:

```bash
ssh -p 2228 nimbus@127.0.0.1 \
  'XDG_RUNTIME_DIR=/run/user/1000 \
   DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
   agent-desktop snapshot --app dolphin'
```

Nunca como fuente de evidencia ni en `install.sh`/`packages.nimbus.*`.
El pointer lab de `docs/HANDOFF.md` queda intacto.
