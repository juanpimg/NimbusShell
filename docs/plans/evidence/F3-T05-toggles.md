# F3-T05 — Control Center: corrección de toggles y parsing real (2026-11-02)

## Estado: RESUELTO

La tarea F3-T05 fue reabierta para asegurar que los toggles reales (Wi-Fi, Bluetooth, Tema oscuro, No molestar) estuvieran completamente probados y verificados.

## Corrección crítica de Bugs de Localización y Sliders
 
- **Causa raíz Wi-Fi SSID descubierta**: En sistemas en español (`LANG=es_ES.UTF-8`), `nmcli -t -f active,ssid dev wifi` produce `sí:<SSID>` en lugar de `yes:<SSID>`. El comando anterior `grep -m1 '^yes'` fallaba sistemáticamente dejando `wifi` como "—". Se solucionó forzando `LC_ALL=C` en las consultas del sistema (`nmcli`, `bluetoothctl`).
- **Causa raíz Wi-Fi Radio descubierta**: `nmcli radio wifi` en sistemas en español devuelve `deshabilitado` cuando la radio Wi-Fi está apagada. La condición anterior `out.indexOf("habilit") >= 0` evaluaba a `true` porque `"deshabilitado"` contiene la subcadena `"habilit"`. Fix: `s.indexOf("habilit") >= 0 && s.indexOf("deshabilit") < 0` junto con matching exacto de `"enabled"`, `"habilitado"`, `"on"`.
- **Protección de sliders (`briSlider`, `volSlider`)**: Se añadieron comprobaciones de seguridad `typeof runner !== "undefined"` en los manejadores `onMoved`, evitando excepciones JavaScript no capturadas cuando `runner` no está en el contexto de ejecución.
- **Normalización de cadenas en `handleOutput`**: Se centralizó el procesamiento en `handleOutput(tag, out)` con `out.trim()` para eliminar retornos de carro antes de las conversiones numéricas de brillo, volumen y batería.
 
 ## Toggles y Comandos Reales
 
 1. **Wi-Fi**: `nmcli radio wifi on/off`.
 2. **Bluetooth**: `rfkill unblock bluetooth 2>/dev/null; bluetoothctl power on` / `bluetoothctl power off`.
 3. **Tema claro/oscuro**: `plasma-apply-colorscheme NimbusTahoeLight` / `plasma-apply-colorscheme NimbusTahoe`.
 4. **No molestar (DND)**: integración con `notifServer.inhibited`.
 5. **Brillo**: fallback a `/sys/class/backlight/*` cuando `brightnessctl` no está instalado o no tiene permisos.
 6. **Volumen**: lectura y ajuste fino con `wpctl`.
 
 ## Verificación
 
 - Test unitario automatizado `tests/qml/tst_controlcenter.qml`:
-   7 PASS / 0 FAIL.
-   Verifica apertura/cierre, toggles, señales `toggled(kind, state)`, parsing robusto de Wi-Fi ("habilitado" vs "deshabilitado"), batería y geometrías Tahoe.
+  - 9 PASS / 0 FAIL.
+  - Verifica apertura/cierre, toggles, señales `toggled(kind, state)`, parsing directo via `handleOutput` de Wi-Fi ("habilitado" vs "deshabilitado", SSID), Bluetooth, tema, volumen, brillo y batería, más geometrías Tahoe.
 - Corregidos errores de layout QML: eliminación de `anchors.fill: parent` en `Row` dentro de `Column` (`briRow` y `volRow`).
 - Protegido el contexto `mpris` para evitar ReferenceError cuando el objeto MPRIS no está registrado.
