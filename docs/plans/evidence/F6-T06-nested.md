# F6-T06 — Portapapeles y emoji · evidencia nested

## Implementación (`apps/nimbus-spotlight/`)
- `nimbusindex.cpp/h`: `clipboardEntries(filter)` en cadena klipper
  `getClipboardHistoryMenu` (+`getClipboardHistoryItem` si existe) →
  `~/.local/share/klipper/history2.lst` (`parseKlipperHistoryFile`,
  tolerante `\n`/NUL, sin vacíos/duplicados) → `wl-paste`; preview
  <16384, `clipType`/`clipDate` (fecha: el menú klipper no la expone →
  gap documentado), búsqueda fuzzy, máx 20. `copyToClipboard()` y
  `activateLocal(copy)` copian el texto COMPLETO (antes truncaba a 80).
- Emoji propios (66, 8 categorías: caras, gestos, animales, comida,
  naturaleza, objetos, símbolos, viajes): `emojiList(term, category)`,
  búsqueda por nombre/keywords ES+EN, recientes (máx 12) persistidas en
  `GenericStateLocation/nimbus-spotlight/emoji-recents.json`; UI con
  `qsTr` (i18n preparada). Sin passwords/Universal Clipboard (R-KRUNNER).
- `Spotlight.qml`: sub-vistas Historial|Emoji en Cmd+4 (sin romper
  Cmd+1..4 ni Quick Keys A–L); Pegar/Copiar copia y cierra; Tab/KRunner
  desactivados en Portapapeles; latencia propia (`clipLatency`).
- `main.cpp`: flags `--tab`/`--clipview` para test determinista.

## Nested (`tests/vm/nested-f6clip.sh`; dbus-run-session, HOME/XDG temp)
- `spikes/nested/f6-clipboard.png`: Historial con 3 entradas de la
  semilla history2.lst (tipo + nº caracteres, Quick Keys, Copiar/Pegar).
- `spikes/nested/f6-emoji.png`: "pizza" → 🍕 (`comida · :pizza:`),
  combo categorías, latencia 0 ms, sin botón KRunner.
- Regresión: pestaña Apps ("kate" → Kate primero, Abrir/Copiar/Revelar,
  fallback KRunner visible, 1 ms). `f6-clip-qmlerr.txt` vacío: 0 errores.
- Pegado: SÍ copiar (unit `copyRoundTrip` Qt round-trip); gap sin
  servidor (sin klipper/wl-paste en nested: autopegado en app destino
  no implementado, solo copiar+cerrar, documentado en QML).

## Tests
- `tst_index` offscreen: 21 passed, 0 failed (nuevos: `clipHistoryParse`,
  `clipFilterNoCrash`, `copyRoundTrip`, `emojiSearch`, `emojiRecentsPersist`).
- `qmllint Spotlight.qml` limpio; build CMake OK, sin warnings nuevos.
