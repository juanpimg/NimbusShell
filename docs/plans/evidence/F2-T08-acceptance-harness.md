# F2-T08 — Arnés de aceptación del sistema instalado

Fecha: 2026-11-01
Rama: `plasma/f-e2e2` (base `1604cb5`)

## Qué se versiona

- `tests/vm/installed-acceptance.sh` — arnés que corre **dentro** de la VM
  instalada, en la sesión Plasma Wayland. Solo lectura; `sudo` únicamente con
  `--mount-share` para montar el 9p en `/mnt/hostshare`.
- `tests/vm/installed-acceptance-report.sh` — lector del JSON en el host
  (tabla o `--md`), sin VM.
- `tests/acceptance/test_installed_acceptance.sh` — tests con fakes en PATH
  (`qdbus6`, `pgrep`, `spectacle`, `systemctl`, `pacman`, `kreadconfig6`,
  `ydotool`, `hostname`, `id`), HOME/XDG temporales y raíz de sistema falsa.

Comprobaciones del arnés: sesión Wayland/Plasma, SDDM enabled, usuario /
hostname / home, skel (`plasma-workspace/env`, autostart, kwinrc, kdeglobals,
klassyrc, kremarc), paquetes `klassy-nimbus` y `krema`, scripts KWin
`nimbus-*Enabled` en la config efectiva, `ColorScheme` + acento,
panel stock (`visible`/`visibilityMode`) y proceso `nimbus-bar`,
`GetServerInformation` (Nimbus vs plasmashell), activación DBus de
Spotlight/Apps/Mission Control (mata daemon y llama `toggle`), KCM Nimbus y
`ydotool`/grupo `input`.

Los atajos reales son opt-in (`--with-shortcuts`): `ydotool key` con
keycodes Linux (sin asumir layout) y capturas `spectacle`. Sin `ydotool`,
`ydotoold` o `spectacle` el check queda **SKIP** y no se envía ninguna tecla.

## Verificación en el host (sin VM)

```console
$ bash -n tests/vm/installed-acceptance.sh
$ bash -n tests/vm/installed-acceptance-report.sh
$ bash -n tests/acceptance/test_installed_acceptance.sh
bash -n: OK (3 scripts)

$ shellcheck -S warning tests/vm/installed-acceptance.sh \
    tests/vm/installed-acceptance-report.sh \
    tests/acceptance/test_installed_acceptance.sh
shellcheck -S warning: 0 warnings (3 scripts)

$ bash tests/acceptance/test_installed_acceptance.sh
ok - PASS: exit 0
ok - PASS: acceptance.json creado
ok - PASS: acceptance.md creado
ok - PASS: JSON válido y veredicto
ok - PASS: markdown con veredicto
ok - report: exit 0 con JSON PASS
ok - report: pinta tabla
ok - report: resumen
ok - FAIL: exit 1
ok - FAIL: paquete y veredicto
ok - report: exit 1 con JSON FAIL
ok - sin ydotool: exit 1 por ydotool.binary
ok - sin ydotool: shortcut SKIP
ok - sin ydotool: spectacle NO se ejecutó
ok - shortcuts: exit 0
ok - shortcuts: PASS y artefactos
ok - shortcuts: spectacle ejecutado
ok - shortcuts: ydotool envió teclas

18 passed, 0 failed
```

El caso PASS del test genera 25 PASS / 0 FAIL / 1 SKIP (atajos no pedidos) y
`acceptance.json` válido (parseado con Python en el propio test). Extracto de
la tabla del lector:

```console
$ bash tests/vm/installed-acceptance-report.sh \
    --json /tmp/.../out-pass/acceptance.json
Aceptación sistema instalado — 2026-11-01T23:45:41Z
Host: nimbusos  Usuario: nimbus  Sesión: wayland/KDE
...
PASS    panel.stock             paneles=1 visible=false visibilityMode=1
PASS    notifications.server    Nimbus: Nimbus/NimbusOS/1.0/1.2
PASS    dbus.spotlight          Spotlight: activado por DBus (pid 4101)
PASS    dbus.apps               Apps: activado por DBus (pid 4102)
PASS    dbus.missioncontrol     Mission Control: activado por DBus (pid 4103)
SKIP    shortcuts.real          no solicitado; usar --with-shortcuts (ydotool + spectacle, sin layout)
Resumen: 25 PASS / 0 FAIL / 1 SKIP — VEREDICTO: PASS
```

Resumen JSON equivalente:

```json
{
  "schema": 1,
  "hostname": "nimbusos",
  "user": "nimbus",
  "session": {"type": "wayland", "desktop": "KDE", "wayland": true, "plasma": true},
  "summary": {"PASS": 25, "FAIL": 0, "SKIP": 1},
  "verdict": "PASS"
}
```

## Comando exacto para la VM instalada

Copiar el arnés al sistema instalado (por 9p o scp) y ejecutarlo como el
usuario `nimbus` en su sesión Plasma Wayland:

```bash
# opción A: compartir el repo por 9p (tag hostshare) y montarlo con sudo
sudo mkdir -p /mnt/hostshare
sudo mount -t 9p -o trans=virtio,version=9p2000.L hostshare /mnt/hostshare
bash /mnt/hostshare/tests/vm/installed-acceptance.sh --mount-share
# -> /mnt/hostshare/e2e/acceptance.json y acceptance.md

# opción B: sin 9p (el script ya está copiado en la VM)
bash ~/installed-acceptance.sh --out "$HOME/aceptacion"

# atajos reales (solo con ydotool + ydotoold + spectacle)
bash ~/installed-acceptance.sh --out "$HOME/aceptacion" --with-shortcuts

# en el host, una vez recogido el JSON:
bash tests/vm/installed-acceptance-report.sh \
  --json /mnt/hostshare/e2e/acceptance.json
```

`--expect-user`/`--expect-host` permiten cambiar los valores esperados
(por defecto `nimbus`/`nimbusos`; `-` desactiva la comparación). `--root`
es solo para tests (raíz de sistema falsa) y no se usa en la VM.

## Límites honestos

- **No ejecutado en la VM en esta tarea**: no hay acceso a la VM instalada
  desde esta worktree. Los tests demuestran la lógica con fakes; la evidencia
  real de aceptación debe generarse con el comando de arriba.
- El arnés mata los daemons Nimbus para probar activación DBus: es aceptable
  en una VM de aceptación, no en una sesión de trabajo.
- `shortcuts.real` acredita que `ydotool` envió keycodes y que `spectacle`
  produjo capturas distintas; la lectura visual final sigue siendo humana.
- Si el sistema instalado solo tiene `~/.config/plasma/kwinrc` (skel) y no
  `~/.config/kwinrc`, `skel.kwinrc` pasa con aviso y `kwin.scripts` falla:
  es un gap real (KWin lee la config efectiva), no un falso verde.
