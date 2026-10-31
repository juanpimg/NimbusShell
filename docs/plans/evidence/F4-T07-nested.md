# F4-T07 nested — reglas de ventana (`kwinrulesrc`)

Fecha: 2026-10-31 (fix ruta: 2026-10-31). Dotfile
`dotfiles/.config/kwinrulesrc` (raíz: ahí lo lee KWin), harness
`tests/vm/nested-f4rules.sh`, foto `spikes/nested/f4-rules.png`.

## Formato real (KWin 6.8.2, `rules.cpp`+`rulesettings.kcfg` upstream)

`[General] count`+`rules`; por regla `Description`, `wmclassmatch`
(0/1/2=ignorar/exacta/subcadena), `types` (Normal=1, Dialog=32,
Utility=256), `placement=Centered`+rule=2 (Force), `size=W,H`+rule=3 y
`maximize*=false`+rule=3 (Apply inicial, no Force — difiere del brief).

## Medidas (`frameGeometry` scripting, 1280x800, `Rule found` confirma 3)

kate (90,65), konsole (117,81), dolphin (143,97), todo 1100x700; kate
exacta al centro del área (1280x770); el resto suma la cascada upstream
(`cascadeIfCovering`, offset área/48) al solaparse total — no es bug.
kdialog 263x103 en (508,363) sin maximizar. Maximize manual: konsole →
(0,30,1280,770), el toggle restaura la regla. Intactos: fullscreen,
CSD (`decorationpolicy` sin tocar), `fsplevel`/`acceptfocus`;
bar/Dock/Spotlight son layer-shell (ninguna regla les aplica).

## Gaps exactos

- Regla 5 sin `Rule found`: kdialog sin padre es Normal en Wayland;
  transient reales y regla 4 (systemsettings, mismo patrón) → VM.
- Maximizar bajo locker da geometría parcial; OK desbloqueado.
  Harness: KWin vuelca a journald (`journalctl _PID=`), y el nested
  arranca bloqueado → `kwin_wayland --no-lockscreen`.
