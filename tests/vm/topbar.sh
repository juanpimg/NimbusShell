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
BHJS="$(mktemp /tmp/nimbus-bh.XXXXXX.js)"
cat >"$BHJS" <<'JS'
var wins = workspace.stackingOrder;
for (var i = 0; i < wins.length; i++) {
    var rc = String(wins[i].resourceClass);
    if (rc.indexOf("nimbus-bar") >= 0 || rc.indexOf("nimbus_bar") >= 0)
        print("NIMBUS_BAR_HEIGHT h=" + wins[i].height + " fh=" + wins[i].frameGeometry.height + " y=" + wins[i].y);
}
JS
BHID="$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript   "$BHJS" nimbus-topbar-bh 2>/dev/null || true)"
if [ -n "$BHID" ]; then
  qdbus6 org.kde.KWin "/Scripting/Script$BHID" org.kde.kwin.Script.run >/dev/null 2>&1 || true
  sleep 0.5
fi
BH="$(journalctl --user -u plasma-kwin_wayland --since '1 min ago' --no-pager   --grep NIMBUS_BAR_HEIGHT 2>/dev/null | tail -n 1 || true)"
rm -f "$BHJS"
if printf '%s' "$BH" | grep -q 'h=24'; then
  ok "bar.height=24 (KWin geometry)"
elif grep -q 'barHeight=24' "$HOME/.local/state/nimbus/bar.log" "$HOME/.cache/nimbus/bar.log" 2>/dev/null; then
  ok "bar.height=24 (log)"
else
  bad "bar.height != 24 (KWin/log): ${BH:-sin dato}"
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
