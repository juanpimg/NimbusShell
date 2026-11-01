# F11-T02 nested — Glass (blur stock, sin Better Blur)

Fecha: 2026-11-01. Rama `plasma/f11-fx`. Mismo harness
`tests/vm/nested-f11fx.sh`. Decision: **blur stock antes de Better Blur**
(contrato §4 + research F11: taj-ny abandonado, xarblu/4v3ngR sin pin;
prohibido `latest`).

## Config (`dotfiles/.config/plasma/kwinrc`)

- `[Plugins] blurEnabled=true` (defecto true; explicito = interruptor
  Reduce Transparency) + `translucencyEnabled=true` (estaba **false** en
  nested: sin el no hay superficies translucidas que difuminar).
- Sin override de fuerza: `BlurStrength/NoiseStrength/Saturation` son las
  claves reales (`kcfg_*` en `kwin_blur_config.so`) pero se dejan al defecto
  KWin (Ruling: ningun numero sin medir; tiers alto/bajo + Better Blur
  quedan para VM con pin de commit).
- Opacidad glass de la barra: `NimbusTokens.glass` (`menuSatMax 1.4`,
  `dockBlurPxEq 15-25 [INFERIDO]`, `dockAdapt/sat/grain [MEDIDO]`,
  `slab*`, `popoverHairline .12/.16`, `sidebarToolbarTint medium` en
  `packages/themes/nimbus-tokens/`); panel stock = tema Breeze
  translucido + blur-behind (sin numero propio aun).
- Toggle Reduce Transparency (canal F8-T05, probado en harness):
  `kwinrc [Plugins] blurEnabled=false` + `qdbus6 org.kde.KWin /KWin
  reconfigure` (sin API dedicada: script/kwriteconfig6; el KCM F8-T05 lo
  expone como "Quitar transparencias"). Reduce Motion = `AnimationSpeed=0`
  (mismo canal).

## Medidas (run 4, `nested-f11fx.log`)

- `f11-glass.png`: krunner FreeFloating (`krunnerrc FreeFloating=true` ya
  estaba) translucido sobre kate, resultados OK.
- `f11-glass-wallpaper.png`: krunner sobre fondo (kate minimizada).
- `f11-glass-reduced-wallpaper.png` vs normal: diff **0 pixeles** (misma
  escena, blur on/off) → con Breeze en nested no hay delta visible: el
  popup/panel no exponen region de blur (fondo Breeze opaco) y/o llvmpipe
  no lo muestra. Sonda BlurStrength=15 + notificacion: (resultado abajo).
- `f11-glass-reduced.png`: modo reducido aplicado
  (`AnimationSpeed=0`, `blurEnabled=false`, reconfigure rc=0) — evidencia
  A9 (label §2.5: springs→fade150, blur→solido).
- Crash-check incluido en T01: 0 crashes.
- fps no medible en nested (llvmpipe) → **se declara para VM**.

## Gaps (para VM, no bloquean)

- Prueba de blur con fondo de contraste o panel translucido dedicado que
  muestre fotones difuminados; pin Better Blur + tiers si el stock no basta
  para Dock/barra (§2.4: blur 15-25px eq, sat 1.25, grano).
- Opacidad numerica propia del panel (hoy la del tema Breeze).

## Sonda BlurStrength=15 + notificacion (2026-11-01, resultado negativo)

- `reconfigureEffect blur` rc=0 (canal vivo), pero `notify-send` fallo en
  nested (`org.freedesktop.Notifications`: timeout — el
  notificationmanager de plasmashell no levanta servicio en sesion
  minima) y ambas capturas salieron identicas (kate, sin banner).
- Conclusion honesta: **blur fotonico no acreditable en nested** con
  clientes stock (krunner/panel Breeze no exponen region de blur visible
  ni con fuerza 15; diff 0px). El efecto esta cargado+soportado y el
  interruptor funciona; la prueba visual con fondo de contraste y la
  decision Better Blur quedan para **VM** (hardening real).
