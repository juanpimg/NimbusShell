# F11-T01 nested — Animaciones macOS (KWin 6.8.2)

Fecha: 2026-11-01. Rama `plasma/f11-fx`. Harness
`tests/vm/nested-f11fx.sh` (KWin virtual 1280×800 + plasmashell/krunner/kate,
dotfiles del repo, `--no-lockscreen`, HOME/XDG temporales, cleanup por trap).
Host bloqueado durante la prueba: el KWin anidado heredaba el lock
(`kscreenlocker_greet --immediateLock`); se aisla con `--no-lockscreen` +
`unset XDG_SESSION_ID/PATH/SEAT*` sin tocar la sesion del usuario.

## Claves reales (KWin 6.8.2 instalado, verificadas en binario/efectos)

- Grupos C++ en **minusculas** (literales UTF-16 en `kwin_wayland`):
  `Effect-magiclamp`, `Effect-glide`, `Effect-blur`, `Effect-overview`;
  formato general `Effect-%1` (visto en `libkwin.so`). El brief pedia
  CamelCase (`[Effect-MagicLamp]`…): **corregido a minusculas**.
- `[Effect-overview]` (no `[Effect-Overview]`): `BorderActivate` vive ahi
  (literal adyacente en binario). La F2 dejo `[Effect-Overview]`: estaba
  ignorado; se corrige aqui.
- JS (fade/scale/maximize/squash/translucency): sin literales en binario;
  grupo `Effect-`+nombre en runtime (KCM `kcm_kwin4_genericscripted.so`
  construye `Effect-`+nombre). Se usa minuscula = Id del metadata.
- Claves: MagicLamp `AnimationDuration` (`kcfg_AnimationDuration` en
  `kwin_magiclamp_config.so`); Glide `Duration/InDistance/InRotationAngle/
  InRotationEdge/OutDistance/OutRotationAngle/OutRotationEdge`
  (`kcfg_*` en `kwin_glide_config.so`; `Duration` defecto 250 en su
  `main.xml`); Fade `FadeWindows/FadeInTime/FadeOutTime` (defectos
  true/150/150 en `fade/contents/config/main.xml`; `main.js` aplica
  `FadeOutTime×4`); Scale `Duration/InScale/OutScale` (defectos 200/0.8/0.8);
  Blur `BlurStrength/NoiseStrength/Saturation` (`kcfg_*` en
  `kwin_blur_config.so`); Overview **sin clave de duracion**
  (solo `OrganizedGrid/FilterWindows/IgnoreMinimized` en
  `kwin_overview_config.so`: su duracion la manda `AnimationSpeed` global).
- `[Plugins]` = `<nombre>Enabled` (convencion F8-T05: `zoomEnabled`,
  `invertEnabled`, `blurEnabled`).
- Exclusividades medidas en metadatas: `minimize={magiclamp,squash}`,
  `toplevel-open-close-animation={glide}` (solo stock); fade/scale/maximize
  sin grupo exclusivo → **componen** (fade+zoom ≈ apertura macOS).

## Config (`dotfiles/.config/plasma/kwinrc`)

- Minimizar: `magiclampEnabled=true` + `[Effect-magiclamp]
  AnimationDuration=350` (§2.5 t-normal); `squashEnabled=false` explicito
  (cede el grupo minimize; estaba activo por defecto).
- Abrir/maximizar: `glideEnabled=true` (`[Effect-glide] Duration=250`,
  §2.5 t-quick) + `scaleEnabled/maximizeEnabled/fadeEnabled=true`
  (componen; fade 150/150 = §2.5 t-instant).
- Overview: `overviewEnabled=true`, `[Effect-overview] BorderActivate=9`;
  sin override de duracion (no existe la clave; MC propio 450ms en F7-T06).
- Global `AnimationSpeed=3`; reduce-motion = `0` (canal F8-T05, §2.5 fade
  150ms). Atajos sin cambios: Overview=none (stock off, MC propio Meta+W
  R-MC-STOCK), Expose=Meta+E, Minimize=Meta+M/Meta+H.

## Medidas (run 4, `nested-f11fx.log`)

- Inventario `isEffectLoaded/isEffectSupported`: magiclamp/glide/fade/
  scale/maximize/blur/overview/slide/translucency = true/true;
  squash = false/true; sheet = false/true. `reconfigureEffect
  magiclamp` rc=0 (reconfig en vivo sin logout).
- `f11-anim-open-1.png`: kate fantasma a media aparicion (glide+scale+
  fade componen); `open-2/restored`: abierta estable.
- `f11-anim-lamp-slow.png`: **morph Magic Lamp a mitad de vuelo**
  (2000ms via reconfigure solo para la foto; `lamp-slow-done` minimizada).
  Prueba que minimize lo posee MagicLamp, no squash/instantaneo.
  A 350ms reales el vuelo termina antes que la latencia de spectacle
  (`min-flight==min-done` a +0.15s/+1.9s: minimizada limpia).
- `f11-anim-overview.png`: Overview stock (Spaces "Escritorio 1" +
  buscador + thumb kate + dim).
- Crash-check: kwin/plasmashell/krunner/kate VIVOS → **0 crashes**.
- fps/video: no medibles en nested (llvmpipe) → **se declaran para VM**.

## Gaps

- Velocidades/fotogramas reales y duracion 350ms cronometrada → VM (A5/A7).
- Sheet (sheets macOS): efecto stock existe pero fuera de alcance (F11
  research: sheets = Klassy/QML); no se activa.
