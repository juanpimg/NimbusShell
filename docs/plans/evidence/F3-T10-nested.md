# F3-T10 nested — OSD volumen/brillo in-situ (contrato §3)

Fecha: 2026-10-31. Rama `plasma/f3-osd`. Harness `tests/vm/nested-osd.sh`
(réplica de `nested-bar.sh`: KWin virtual 1280×800 + plasmashell, HOME/XDG
temporales, `--no-lockscreen`, cleanup; exige `QT_FORCE_STDERR_LOGGING=1`
o el log de la barra sale vacío — quirk Qt ya visto en F3-T05-fix).

Ficheros: `packages/shell/nimbus-bar/qml/OSD.qml` (burbuja glass 280×56,
icono+slider+valor, auto-oculta 1.5s, sin foco, clic-fuera+Esc) + `Bar.qml`
+ `bar.qrc` + `osdbridge.h` (adaptor `org.nimbus.OSD`, objeto `/OSD`,
`show(kind,value)`) + `main.cpp` (`--demo-osd volume|brightness`) +
`scripts/nimbus-osd.sh` (teclas multimedia; binding real: Ajustes →
Teclado → Atajos → Orden con disparadores `XF86AudioRaiseVolume/Lower/
Mute`, `XF86MonBrightnessUp/Down`). Canales nested: volumen GAP (sin PipeWire/Pulse: `wpctl` no conecta,
`pactl` refused → OSD conserva valor DBus 70%); brillo REAL vía fallback
sysfs (`/sys/class/backlight/nvidia_wmi_ec_backlight` 100/100; sin
`brightnessctl` en nested — el `||` con cut/tr nunca falla, por eso el
fallback va en variable).

Capturas: `spikes/nested/f3-osd-volume.png` (V + slider + "Volumen 70%")
y `f3-osd-brightness.png` (B + slider lleno + "Brillo 100%" real). Barra 24 intacta; `nested-osd-bar.log` sin errores
QML (solo avisos benignos de tema nested). `qmllint` 0, `bash -n` OK,
build+install OK.

Commit: `feat(F3-T10): OSD volumen y brillo en barra`. Límites VM: sin audio (volumen no verificable real); sysfs comparte el
kernel del host (brillo 100% es del host); detección de foco/Esc no medida
(scrim reutiliza patrón Calendar verificado); `ControlCenter.qml` conserva
el bug `brightnessctl … || echo —` (fuera de alcance).
