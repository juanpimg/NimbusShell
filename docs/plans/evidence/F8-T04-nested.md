# F8-T04 — Evidencia nested (Atajos reales)

## Controles
- Toggle ⌘ Cmd (Meta, defecto, cero atajos Ctrl nuevos) / Ctrl (opt-in)
  → en `save()` corre `scripts/nimbus-keys --apply --toggle-cmd
  <meta|ctrl> --home $HOME` (R-CTRL: sin `CTRL-*` nuevos por defecto).
  Sin el script en PATH solo se avisa si se pide modo Ctrl.
- Detección al abrir: heurística sobre `kglobalshortcutsrc [kwin]
  "Window Close"` (contiene `Meta` ⟺ modo Cmd).
- Chuleta con los 8 atajos de la TABLE de `nimbus-keys`; botón
  «Editor avanzado» (`kcm_keys`, salto con aviso si no existe).
- Nota honesta: aplica con «Aplicar» y rige tras reiniciar sesión
  (kglobalaccel lee al iniciar); `Predeterminados` = meta.

## Tests (dentro de `test-pages.sh`, 24/24 PASS)
`shortcuts-ctrl` → `Window Close=Ctrl+Q,…`; `shortcuts-meta` →
`Window Close=Meta+Q,…` (nimbus-keys real sobre HOME temporal).
Trampa cazada: al script le faltaba `--apply` (sin él solo hace
`--check` y falla si no existe el destino) — corregido en el KCM.
Lectura fiel medida: en HOME virgen nested, KWin escribe atajos stock
(`Alt+F4`) y el KCM muestra Ctrl; el harness siembra el estado canónico
(`nimbus-keys --apply --toggle-cmd meta --home`) como en un sistema
Nimbus real (igual que `nested-plasma.sh` despliega dotfiles).

## Captura
`spikes/nested/f8-kcm-shortcuts.png`: KCM abierto en Atajos
(⌘ Cmd marcado + chuleta); `QML_ERRORS=0`.
