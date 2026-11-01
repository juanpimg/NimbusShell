#!/usr/bin/env bash
# test_theme.sh (F2-T02): valida el tema SDDM Nimbus sin tocar el host.
# Sin root, sin sudo, sin red. Solo lectura + herramientas presentes.
# Cubre: ficheros requeridos, QtVersion=6 en metadata, theme.conf,
# qmllint de los QML y, si hay sddm-greeter(-qt6), test-mode offscreen.
# Salta (exit 0) lo que necesite herramienta ausente; falla solo ante regresión.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
THEME="$REPO_ROOT/packages/themes/sddm-nimbus"
FAILS=0

pass() { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1" >&2; FAILS=$((FAILS + 1)); }
skip() { echo "  [SKIP] $1"; }

need() { command -v "$1" >/dev/null 2>&1 || { skip "falta $1 ($2)"; return 1; }; }

echo "== sddm-nimbus: ficheros =="
for f in Main.qml theme.conf metadata.desktop qmldir NimbusTokens.qml \
         components/LoginClock.qml components/UserSelector.qml \
         components/SessionBar.qml Background.jpg; do
  [ -f "$THEME/$f" ] && pass "existe $f" || fail "falta $f"
done

echo "== sddm-nimbus: metadata (SDDM 0.21 exige QtVersion=6) =="
if grep -q '^QtVersion=6' "$THEME/metadata.desktop" 2>/dev/null; then
  pass "QtVersion=6 declarado"
else
  fail "metadata.desktop sin QtVersion=6 (SDDM 0.21 cae al greeter Qt5)"
fi
grep -q '^MainScript=Main.qml' "$THEME/metadata.desktop" 2>/dev/null \
  && pass "MainScript=Main.qml" || fail "sin MainScript"
grep -q '^ConfigFile=theme.conf' "$THEME/metadata.desktop" 2>/dev/null \
  && pass "ConfigFile=theme.conf" || fail "sin ConfigFile"

echo "== sddm-nimbus: sin Controls/SddmComponents (greeter real) =="
if grep -rq 'import SddmComponents\|import QtQuick.Controls' "$THEME/Main.qml" "$THEME/components/" "$THEME/NimbusTokens.qml" 2>/dev/null; then
  fail "import SddmComponents/Controls presente (rompe el greeter real)"
else
  pass "solo QtQuick (+Layouts) y tipos propios"
fi
if grep -rn 'contentItem\|[^_a-zA-Z]background:' "$THEME/Main.qml" "$THEME/components/"*.qml 2>/dev/null | grep -vE ':[0-9]+:\s*//'; then
  fail "queda contentItem/background de Controls (ver arriba)"
else
  pass "sin contentItem/background de Controls"
fi

echo "== sddm-nimbus: roles UserModel SDDM 0.21 (Name=+1, RealName=+2) =="
if grep -q 'UserRole + 3' "$THEME/Main.qml" 2>/dev/null; then
  fail "Main.qml usa UserRole+3 (HomeDir, no usuario)"
else
  pass "sin UserRole+3"
fi

echo "== sddm-nimbus: qmllint =="
if need qmllint "lint QML"; then
  if qmllint "$THEME/Main.qml" "$THEME/NimbusTokens.qml" \
             "$THEME/components/"*.qml >/dev/null 2>&1; then
    pass "qmllint limpio"
  else
    fail "qmllint con errores"
  fi
fi

echo "== sddm-nimbus: greeter --test-mode (si hay binario) =="
GREETER=""
for b in sddm-greeter-qt6 sddm-greeter; do
  if command -v "$b" >/dev/null 2>&1; then GREETER="$b"; break; fi
done
if [ -z "$GREETER" ]; then
  skip "sin sddm-greeter en el host (test-mode diferido a VM)"
else
  if [ -z "${DISPLAY:-}" ] && ! command -v Xvfb >/dev/null 2>&1; then
    skip "sin DISPLAY ni Xvfb para $GREETER"
  else
    need qml "harness" >/dev/null || true
    OUT="$(mktemp -d)/greeter.png"
    if [ -z "${DISPLAY:-}" ]; then
      XVFB=:99
      Xvfb "$XVFB" >/dev/null 2>&1 &
      XVPID=$!
      sleep 1
      DISPLAY="$XVFB" timeout 20 "$GREETER" --test-mode --theme "$THEME" >/dev/null 2>&1
      RC=$?
      kill "$XVPID" 2>/dev/null
    else
      QT_QPA_PLATFORM=offscreen timeout 20 "$GREETER" --test-mode \
        --theme "$THEME" >/dev/null 2>&1
      RC=$?
    fi
    [ "$RC" -eq 0 ] && pass "$GREETER --test-mode exit 0" \
      || fail "$GREETER --test-mode exit $RC"
    rm -f "$OUT"
  fi
fi

echo "== resultado: FAILS=$FAILS =="
[ "$FAILS" -eq 0 ]
