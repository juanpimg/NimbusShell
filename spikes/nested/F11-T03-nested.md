# F11-T03 — Estados, dark/light y acento en la barra (nested)

Tokens (`NimbusTokens.qml` + espejo md5 en `nimbus-tokens/` + `tokens.json`):
`states.hoverAlpha .12 / pressedAlpha .24 / selectedAlpha .85` + `disabledOpacity
[0.3,0.5] / focusRingPx 2 / focusContrast 3` [HIG §2.5]; `accentCustom` + `accentColor()`;
derivados `barBg/popupBg/popupBorder/hairline/hoverFill/pressedFill/selectedFill/subText/faintText/disabledText`.
Componentes (`nimbus-bar/qml/`): Menu/GlobalMenu/StatusArea/Calendar/CC/OSD y `Bar.qml`
usan solo tokens (hover=accent, pressed=interno, disabled sin hover, foco anillo accent
2px + `Keys.onReturn`, `activeFocusOnTab`); `dark` se sincroniza desde kdeglobals
(`CC.refresh` → `ColorScheme`, verificado en log: `BreezeLight/BreezeDark`); `--accent <hex>`
(`main.cpp` → `customAccent`) tiñe logo/tiles/today/focos/sliders/OSD.
Capturas `spikes/nested/`: `f11-states-light/dark.png` (menu+CC, scheme visible en tile),
`f11-states-accent.png` (logo N naranja + OSD Volumen 70% con icono naranja),
`f11-states-matrix-light/dark.png` (matriz QML: popup/hover/pressed/selected/disabled/foco 2px).
Tests: `tests/qml/tst_f11states.qml` 10/10 (tokens + componentes reales con stubs);
`qmllint` 0 avisos (8 ficheros); `shellcheck` limpio; 0 errores QML en nested.
Harness: `tests/vm/nested-f11states.sh` + `f11-states-matrix.qml.tmpl`.
Límites: hover/pressed reales de puntero no se inyectan (estados vía tokens + matriz);
StatusArea solo en nested (exige SNI real); `/tmp/nimbus-bar-prefix` lo pisa otra sesión →
binario propio en `/tmp/nimbus-bar-f11states` (verificar con `strings -e l`); `grabToImage`
no completa en offscreen (capturas vía spectacle); GlobalMenu drill-in sigue pendiente (F3-T06).
