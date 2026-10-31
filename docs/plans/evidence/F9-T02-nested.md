# Evidencia F9-T02 — wizard de primer arranque (`apps/nimbus-welcome`)

## Qué se implementó
- `apps/nimbus-welcome/`: Qt6 Quick sin KF (CMake + `main.cpp` +
  `welcomebackend.{h,cpp}` + `qml/Welcome.qml` + `qml/I18n.js` + `welcome.qrc`).
- 6 pasos: Bienvenida, Idioma (es/en), Wi-Fi (scan/connect `nmcli`, simulado
  en test), Cuenta (nombre + avatar con FileDialog), Apariencia
  (claro/oscuro + 5 acentos; aplica con `scripts/nimbus-theme` si existe, si
  no `kwriteconfig6`, en test simula), Final (4 apps con check sin instalar
  + tour con atajos).
- Progreso: 6 puntos + barra animada + `N de 6 · paso`; Atrás/Siguiente/
  Omitir; Terminar/Skip cierran la app (`requestQuit`).
- Persistencia `~/.config/nimbus-welcome.ini` (`wizard/step`, `completed`,
  `user/`, `look/`, `apps/`, `wifi/`): reanuda el paso al reiniciar; si
  `completed` y sin `--demo`/`--page`/`--shot`, sale con 0 (autostart no-op).
- i18n: `I18n.js` con claves = cadena fuente es + dict `en`; `setLang` +
  re-traducción en vivo (ZWSP); preparado para ki18n/.ts (F11-T05).
- Tokens Tahoe inline (contrato §2 [HIG]): label/accent/bg/bg2 light+dark,
  radios 12, Inter, escala 4/8/12/16/20/24/32; logo N propio (R-APPLE).
- Flags: `--demo` (reabrir), `--page <n|nombre>`, `--shot <png>`,
  `--reset`. `NIMBUS_WELCOME_SIM=1` = test: sin red, sin sistema, sin paquetes.

## Verificación (todo en ramales temporales, host intacto)
- `qmllint qml/Welcome.qml` → OK (1 fix: `minimumWidth` no existe en
  TextField → `Layout.preferredWidth`; paleta hoisted en `c` por qmllint
  era-Qt5, como F3-T01).
- `cmake -S . -B build && cmake --build build && ctest` → `tst_welcome`
  4/4 passed (límites de paso, progreso+reanudar, skip/finish+quit,
  wifi simulado).
- Funcional offscreen (`QT_QPA_PLATFORM=offscreen`, HOME temporal):
  `--reset --demo --page appearance` → `STEP=4`; reinicio sin `--page` →
  `STEP=4` (reanuda); `completed=true` sin `--demo` → rc=0 sin abrir;
  `--demo` reabre. 0 errores QML en los 4 runs.
- Nested Wayland (`kwin_wayland --virtual` + `dbus-run-session`, HOME/XDG
  temporales, trap cleanup, `NIMBUS_WELCOME_SIM=1`, script en
  `/tmp/opencode/f9t02-nested.sh`): 0 errores QML; `STEP=0` y `STEP=4`.

## Capturas
- `spikes/nested/f9-welcome-1.png` (bienvenida, paso 1/6).
- `spikes/nested/f9-welcome-appearance.png` (apariencia, paso 5/6, dark).
- Log: `spikes/nested/f9-welcome-nested.log`.
- Fix visual medido en captura: texto RadioButton apagado en dark →
  `contentItem` explícito con `c.label` (verificado en re-shot).

## Límites
- Sin autostart `.desktop` instalado (lo decide la ISO, no esta tarea).
- Sin `plasma-apply-*` en vivo desde el wizard (solo `nimbus-theme`
  detached o config por fichero); sin instalar paquetes (checks informativos).
- `build/` no se commitea (como nimbus-spotlight).
