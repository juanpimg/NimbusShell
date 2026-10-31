# NESTED-PLASMA — harness Plasma anidado (F0)

Fecha: 2026-10-31. Host: Plasma 6.8.2 Wayland. Harness: `tests/vm/nested-plasma.sh`.

## Resultado: SÍ funciona

3 lanzamientos (intento 1: flag inválido; intento 2: verde; intento 3 tras fix
de cleanup: verde + sin restos). KWin 6.8.2 virtual 1280x800 con socket
`nimbus-nested`, bus D-Bus privado (`dbus-run-session`), `XDG_*` temporales
(`~/.config` del host intacto, sin `--replace`, sin root).

Intento final: `kwin_wayland`, `plasmashell`, `krunner`, `kate` los 4 VIVO;
`qdbus6 org.kde.KWin /KWin supportInformation` responde (ES); `spectacle -b -n`
captura PNG 1280x800 (434 KB) con wallpaper, panel inferior (reloj), krunner
arriba y ventana Kate. Evidencia: `spikes/nested/nested-plasma.png` (+ `.log`,
`result.env`). Cleanup verificado: 0 procesos `kwin_wayland --virtual`, 0
dirs `/tmp/opencode/nimbus-nested-*` tras salir.

## Hallazgos (2, ambos fixeados en el script)

1. `plasmashell --no-startup-id` → `Opción desconocida`; plasmashell-6 no lo
   acepta. Fix: lanzar `plasmashell` sin flags.
2. Los hijos sobrevivían a `dbus-run-session` (pidfile vacío en el padre +
   `pkill -f WAYLAND_DISPLAY=...` ineficaz; además `pkill -f` con patrón
   presente en la propia cmdline se automata — no usar). Fix: `trap 'kill
   $(jobs -p)' EXIT` interno + pidfile + `ps|grep "[k]win..."` externo.

## No verificado

Overview (Meta+W): sin `ydotool`/`kdotool`/`wtype` en el host y prohibido
instalar; queda documentado como paso manual (abrir el anidado y pulsar
Meta+W, o `qdbus6 org.kde.KWin /Effects ...` en el bus anidado). Fallback
`ScreenShot2` vía qdbus no hizo falta (spectacle OK).

## Riesgos

- Los anidados comparten GPU del host; fps/efectos no representativos de VM.
- `kate`/`krunner` anidados son indistinguibles por nombre de los del host:
  el cleanup usa pidfile + patrón kwin; no matar por nombre jamás.
- `xdg-desktop-portal` avisa `Failed to connect to PipeWire` en el anidado
  (benigno para capturas/valores).
