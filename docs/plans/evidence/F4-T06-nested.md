# F4-T06 nested — ventanas inactivas

Fecha: 2026-10-31. Rama `plasma/f4-windows`. Mismo harness que F4-T02
(preset `NimbusTahoe` final). Comparativa kate activa
(`f4-titlebar-active.png`) vs kate inactiva + konsole activa
(`f4-titlebar-inactive.png`). Medidas PIL.

| Ítem | Contrato | Medido | Estado |
|---|---|---|---|
| círculos inactivos | gris #8E8E93 | **(142,142,147)** sólido | OK |
| círculos activos | R/A/V | (255,95,87)/(254,188,46)/(40,200,64) | OK (ref) |
| glifos en reposo | ninguno | 9 colores/caja = R+bg+antialias (act e inact) | OK |
| bg titlebar act/inact | — | (239,240,241) ambas (opacity 100, sin dim) | OK |
| texto título act/inact | — | #232629-ish ambas (sin clave kcfg: color-scheme) | OK (sin diff) |
| contenido kate act/inact | sin dim | **(35,38,41) idéntico** | OK |
| sombra inactiva | — | Large/128 (sin medir; más suave por strength) | ref |

Nota: el terminal de konsole SÍ se oscurece al perder foco (46→35
medido en 5 puntos). Es app-level (kate no cambia ⇒ no hay dim global
de KWin ni de la deco, que no tiene tal clave — ver F4-T02). No bloquea.

Diferenciador activo/inactivo resultante: color de círculos + fuerza
de sombra + (en apps Qt) paleta inactiva propia. Titlebar y título no
cambian (opacity 100, sin clave de color).
