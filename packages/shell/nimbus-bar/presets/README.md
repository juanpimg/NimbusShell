# Presets de la barra Nimbus (F3-T13, R-BAR-PRESETS)

Colorizer/WindowButtons6 NO aplican: no hay panel Plasma (R-TOPBAR-LAYER,
barra layer-shell propia). Los presets se versionan aquí y se aplican con
`scripts/nimbus-bar-preset` a `~/.config/nimbus-bar/preset.json`, que la
barra lee al arrancar (`barPresetJson` en `main.cpp`, binding en `Bar.qml`).

## Esquema `nimbus-bar-preset/1`

| Clave | Tipo | Rango / valores | Descripción |
|---|---|---|---|
| `schema` | string | `"nimbus-bar-preset/1"` exacto | Versión del esquema |
| `name` | string | `default\|compact\|minimal` (+custom) | Nombre del preset |
| `description` | string | no vacío | Descripción corta |
| `bar.height` | int | 16..32 | Altura de la barra (canónico 24, contrato §3) |
| `bar.marginLeft/Right` | int | 0..32 | Márgenes laterales |
| `bar.spacingLeft/Right` | int | 0..32 | Espaciado de las cajas izq/der |
| `bar.bgAlpha` | real | 0..1 | Alfa del fondo glass oscuro ([INFERIDO] 0.55) |
| `bar.hairlineAlpha` | real | 0..1 | Alfa del hairline inferior (§2.1) |
| `clock.format` | string | formato `Qt.formatTime/Date` no vacío | Formato del reloj |
| `icons.order` | [string] | subconjunto de `wifi,bluetooth,controlcenter,battery,tray,clock`, sin duplicados | Orden de la caja derecha |
| `icons.hidden` | [string] | subconjunto de `order` | Iconos ocultos |
| `osd.width/height` | int | 100..600 / 24..200 | Tamaño de la burbuja OSD |
| `osd.timeoutMs` | int | >0 | Auto-ocultado del OSD (canónico 1500) |
| `glass.tint` | string | `dark\|light` | Tinte del glass |
| `glass.blurPxEq` | [int,int] | dos enteros ≥0 | Blur equivalente Dock [INFERIDO] |

Toda clave ausente o inválida en `preset.json` cae al valor previo del
código (fallbacks en `Bar.qml`/`OSD.qml`, sin valores mágicos nuevos).
La validación vive en `scripts/nimbus-bar-preset --check` y en
`tests/bar/test_presets.sh` (python3 stdlib, sin dependencias).

## Pin de versiones (R-BAR-PRESETS)

| Componente | Pin | Dónde se verifica |
|---|---|---|
| Qt | 6.12 | `qmake6 --version` / `/usr/lib/qt6` |
| LayerShellQt | 6.8.2 | `LayerShellQtConfigVersion.cmake` (`PACKAGE_VERSION`) |
| Krema (Dock) | 0.12.0 | versión documentada en `docs/plans/evidence/F0-T03.md` |
| Klassy (fallback deco) | 6.7.3 | `libklassycommon6.so.6.7.3` en `docs/plans/evidence/F2-T01.md` |

`scripts/nimbus-bar-preset --pin-check` compara `../pins.txt` contra el
sistema (Qt/LayerShellQt, solo si están instalados) y contra el repo
(Krema/Klassy, textual): no instala nada, exit 1 con contexto si diverge.
