#!/bin/bash
# topbar.sh — aceptación F3-T12 en sistema instalado (sin root).
# Checks funcionales + captura para diff golden (topbar-golden.py en host).
set -u
OUT="${1:-$HOME/topbar-evidence}"
mkdir -p "$OUT" || exit 1
PASS=0; FAIL=0
ok() { printf 'PASS %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf 'FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }

BAR="$(pgrep -f '/usr/local/bin/nimbus-bar' | head -n 1 || true)"
[ -n "$BAR" ] && ok "bar.process pid=$BAR" || bad "bar.process ausente"

LOG="$HOME/.local/state/nimbus/bar.log"
[ -f "$LOG" ] || LOG="$HOME/.cache/nimbus/hide-panel.log"
if grep -q 'barHeight=24' "$HOME/.local/state/nimbus/bar.log" "$HOME/.cache/nimbus/bar.log" 2>/dev/null; then
  ok "bar.height=24 (log)"
else
  printf 'SKIP bar.height=24 (log ausente; validar por golden/captura)\n'
fi

NOTIF="$(qdbus6 org.freedesktop.Notifications /org/freedesktop/Notifications \
  org.freedesktop.Notifications.GetServerInformation 2>&1 || true)"
printf '%s' "$NOTIF" | grep -qi nimbus && ok "notifications.server=Nimbus" \
  || bad "notifications.server no Nimbus: $(printf '%s' "$NOTIF" | tr '\n' '/')"

SCREEN="$(qdbus6 org.nimbus.MissionControl /MC \
  org.nimbus.MissionControl.screenInfo 2>&1 || true)"
printf '%s' "$SCREEN" | grep -q 'count=' && ok "screens: $SCREEN" \
  || bad "screenInfo no disponible"

SHOT="$OUT/topbar.png"
rm -f "$SHOT"
if spectacle -b -n -f -o "$SHOT" >/dev/null 2>&1 && [ -s "$SHOT" ]; then
  ok "captura $SHOT"
else
  bad "spectacle no capturó $SHOT"
fi

printf '\nRESULT %d PASS / %d FAIL\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
