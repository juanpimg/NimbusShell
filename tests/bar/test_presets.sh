#!/usr/bin/env bash
# test_presets.sh (F3-T13): presets y pin de la barra Nimbus.
# Sin host: todo con --home temporal; sin sudo, sin red. No instala nada.
# Cubre: JSON válidos + esquema, --list/--apply/--check/--reset (+idempotencia),
# --pin-check, qmllint de la barra, build cmake y --dump-preset por preset
# (binding real: altura, reloj, orden visual, visibilidad, OSD, fallbacks).
# Salta (exit 0) lo que necesite herramienta ausente; falla solo ante regresión.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PRESET="$REPO_ROOT/scripts/nimbus-bar-preset"
BAR_SRC="$REPO_ROOT/packages/shell/nimbus-bar"
PRESET_DIR="$BAR_SRC/presets"
FAILS=0

pass() { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1" >&2; FAILS=$((FAILS + 1)); }
skip() { echo "  [SKIP] $1"; }

need() { command -v "$1" >/dev/null 2>&1 || { skip "falta $1 ($2)"; return 1; }; }

echo "== presets: esquema =="
if need python3 "validación JSON"; then
  for f in "$PRESET_DIR"/*.json; do
    if [ ! -f "$f" ]; then fail "sin presets en $PRESET_DIR"; break; fi
  done
  for p in default compact minimal; do
    [ -f "$PRESET_DIR/$p.json" ] && pass "existe $p.json" || fail "falta $p.json"
  done
fi

echo "== presets: script =="
if need python3 "script requiere python3"; then
  T="$(mktemp -d)"
  list="$("$PRESET" --list)"
  [ "$list" = "$(printf 'compact\ndefault\nminimal')" ] && pass "--list" || fail "--list ($list)"
  "$PRESET" --apply --preset compact --home "$T" >/dev/null || fail "--apply compact"
  cmp -s "$PRESET_DIR/compact.json" "$T/.config/nimbus-bar/preset.json" \
    && pass "--apply escribe preset.json" || fail "--apply contenido"
  out="$("$PRESET" --apply --preset compact --home "$T")" \
    && case "$out" in *"sin cambios"*) pass "--apply idempotente" ;; *) fail "--apply idempotente ($out)" ;; esac
  "$PRESET" --check --home "$T" >/dev/null && pass "--check verde" || fail "--check verde"
  echo '{"schema":"nimbus-bar-preset/1"}' > "$T/.config/nimbus-bar/preset.json"
  "$PRESET" --check --home "$T" >/dev/null 2>&1 \
    && fail "--check acepta esquema roto" || pass "--check rechaza esquema roto"
  "$PRESET" --apply --preset inexistente --home "$T" >/dev/null 2>&1 \
    && fail "--apply acepta preset inexistente" || pass "--apply rechaza preset inexistente"
  "$PRESET" --apply --preset default --home "$T" >/dev/null || fail "--apply default"
  "$PRESET" --reset --home "$T" >/dev/null || fail "--reset"
  cmp -s "$PRESET_DIR/compact.json" "$T/.config/nimbus-bar/preset.json" \
    && pass "--reset restaura backup (compact)" || fail "--reset restaura backup"
  "$PRESET" --reset --home "$T" >/dev/null || fail "--reset (2, idempotente)"
  cmp -s "$PRESET_DIR/compact.json" "$T/.config/nimbus-bar/preset.json" \
    && pass "--reset idempotente (sigue compact)" || fail "--reset idempotente"
  T2="$(mktemp -d)"
  "$PRESET" --apply --preset default --home "$T2" >/dev/null || fail "--apply default (T2)"
  "$PRESET" --reset --home "$T2" >/dev/null || fail "--reset sin backup (T2)"
  [ ! -f "$T2/.config/nimbus-bar/preset.json" ] \
    && pass "--reset sin backup elimina" || fail "--reset sin backup elimina"
  rm -rf "$T2"
  rm -rf "$T"
fi

echo "== presets: pin =="
if need python3 "pin-check requiere python3"; then
  if "$PRESET" --pin-check >/dev/null 2>&1; then pass "--pin-check";
  else fail "--pin-check (ver scripts/nimbus-bar-preset --pin-check)"; fi
fi

echo "== presets: qmllint =="
if need qmllint "lint QML"; then
  ok=1
  for f in "$BAR_SRC"/qml/Bar.qml "$BAR_SRC"/qml/OSD.qml; do
    qmllint "$f" >/dev/null 2>&1 || { echo "  [FAIL] qmllint $f" >&2; ok=0; }
  done
  [ "$ok" = "1" ] && pass "qmllint Bar+OSD" || FAILS=$((FAILS + 1))
else
  :
fi

echo "== presets: build + binding (--dump-preset) =="
if need cmake "build nimbus-bar" && need python3 "preset JSON"; then
  if [ ! -f /usr/lib/cmake/LayerShellQt/LayerShellQtConfigVersion.cmake ]; then
    skip "sin LayerShellQt (build solo con dev files)"
  else
    B="$(mktemp -d)"
    if ! cmake "$BAR_SRC" -DCMAKE_BUILD_TYPE=Release -B "$B/build" >/dev/null 2>&1; then
      fail "cmake configure"
    elif ! cmake --build "$B/build" -j"$(nproc)" >/dev/null 2>&1; then
      fail "cmake build"
    else
      pass "build nimbus-bar"
      BIN="$B/build/nimbus-bar"
      T="$(mktemp -d)"
      dump() { # $1 = preset aplicado o "" (sin preset)
        if [ -n "$1" ]; then "$PRESET" --apply --preset "$1" --home "$T" >/dev/null || return 1; fi
        XDG_CONFIG_HOME="$T/.config" QT_QPA_PLATFORM=offscreen \
          timeout 20 "$BIN" --dump-preset 2>&1
      }
      chk() { # $1 etiqueta, $2 dump, $3..: patrones grep -qE (todos deben casar)
        label="$1"; text="$2"; shift 2
        for pat in "$@"; do
          printf '%s\n' "$text" | grep -qE "$pat" || { fail "$label (falta /$pat/ en: $(printf '%s' "$text" | tr '\n' '|'))"; return; }
        done
        pass "$label"
      }
      d="$(dump default)" && chk "binding default" "$d" \
        "name=default height=24 clockFormat=ddd d MMM HH:mm" \
        "rightBox=wifiItem:1,btItem:1,ccButton:1,batteryItem:1,tray:1,clock:1" \
        "osd=280x56 timeout=1500"
      d="$(dump compact)" && chk "binding compact" "$d" \
        "name=compact height=24 clockFormat=HH:mm" \
        "rightBox=wifiItem:1,btItem:0,ccButton:1,batteryItem:1,tray:1,clock:1"
      d="$(dump minimal)" && chk "binding minimal" "$d" \
        "name=minimal height=20 clockFormat=HH:mm" \
        "rightBox=wifiItem:0,btItem:0,ccButton:0,batteryItem:1,tray:1,clock:1" \
        "osd=240x48 timeout=1200"
      rm -f "$T/.config/nimbus-bar/preset.json"
      d="$(dump '')" && chk "fallback sin preset" "$d" \
        "height=24 clockFormat=HH:mm" "osd=280x56 timeout=1500"
      echo '{no json' > "$T/.config/nimbus-bar/preset.json"
      d="$(dump '')" && chk "fallback corrupto" "$d" \
        "height=24 clockFormat=HH:mm" "osd=280x56 timeout=1500"
      rm -rf "$T"
    fi
    rm -rf "$B"
  fi
fi

echo
if [ "$FAILS" = "0" ]; then echo "PRESETS VERDE."; exit 0; else echo "PRESETS ROJO: $FAILS fallo(s)." >&2; exit 1; fi
