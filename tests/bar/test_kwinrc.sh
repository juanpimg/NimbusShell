#!/usr/bin/env bash
# test_kwinrc.sh (F3-T03 + F6-T06): kwinrc efectivo, panel auto-hide e input.
# Sin root, sin red, sin tocar el HOME real: HOME temporal y qdbus6 falso.
# Cubre:
#   1. dotfiles/.config/kwinrc == dotfiles/.config/plasma/kwinrc (cmp, sin drift)
#      y las claves nimbus-*Enabled llegan al fichero que KWin lee de verdad.
#   2. iso/build-iso.sh exige/stagea el kwinrc efectivo y el autostart.
#   3. nimbus-installed-setup copia plasma/kwinrc -> .config/kwinrc si falta,
#      fija Klassy en ambos y aplica el grupo input fuera del timer de tema.
#   4. nimbus-hide-panel: detecta paneles por print(panels().length), reintenta,
#      loguea y devuelve error real si evaluateScript falla.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KWINRC="$REPO_ROOT/dotfiles/.config/kwinrc"
KWINRC_PLASMA="$REPO_ROOT/dotfiles/.config/plasma/kwinrc"
KDEGLOBALS="$REPO_ROOT/dotfiles/.config/kdeglobals"
KDEGLOBALS_PLASMA="$REPO_ROOT/dotfiles/.config/plasma/kdeglobals"
KGSHORTCUTS="$REPO_ROOT/dotfiles/.config/kglobalshortcutsrc"
KGSHORTCUTS_PLASMA="$REPO_ROOT/dotfiles/.config/plasma/kglobalshortcutsrc"
SETUP="$REPO_ROOT/iso/profile/airootfs/usr/local/bin/nimbus-installed-setup"
HIDE="$REPO_ROOT/iso/profile/airootfs/usr/local/bin/nimbus-hide-panel"
BUILD_ISO="$REPO_ROOT/iso/build-iso.sh"
AUTOSTART="$REPO_ROOT/dotfiles/.config/autostart/nimbus-hide-panel.desktop"
FAILS=0

pass() { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1" >&2; FAILS=$((FAILS + 1)); }
skip() { echo "  [SKIP] $1"; }

echo "== kwinrc: efectivo vs canónico =="
if [ -f "$KWINRC" ] && [ -f "$KWINRC_PLASMA" ]; then
    if cmp -s "$KWINRC" "$KWINRC_PLASMA"; then
        pass "dotfiles/.config/kwinrc == plasma/kwinrc (cmp)"
    else
        fail "kwinrc efectivo y plasma/kwinrc divergen (cmp); copia el canónico"
    fi
else
    fail "falta dotfiles/.config/kwinrc o plasma/kwinrc"
fi
for key in nimbus-spotlightEnabled nimbus-apps-toggleEnabled \
           nimbus-tabsEnabled nimbus-mcEnabled nimbus-zoomEnabled; do
    if grep -qx "$key=true" "$KWINRC" 2>/dev/null; then
        pass "kwinrc efectivo: $key=true"
    else
        fail "kwinrc efectivo sin $key=true (KWin no cargará el script)"
    fi
done
if grep -q "KWin lee ~/.config/kwinrc" "$KWINRC" 2>/dev/null; then
    pass "kwinrc efectivo con cabecera de duplicado documentada"
else
    fail "kwinrc efectivo sin cabecera 'KWin lee ~/.config/kwinrc'"
fi
if [ -f "$KDEGLOBALS" ] && [ -f "$KDEGLOBALS_PLASMA" ]; then
    if cmp -s "$KDEGLOBALS" "$KDEGLOBALS_PLASMA"; then
        pass "dotfiles/.config/kdeglobals == plasma/kdeglobals (cmp)"
    else
        fail "kdeglobals efectivo y plasma/kdeglobals divergen (cmp)"
    fi
else
    fail "falta dotfiles/.config/kdeglobals o plasma/kdeglobals"
fi
if [ -f "$KGSHORTCUTS" ] && [ -f "$KGSHORTCUTS_PLASMA" ] && cmp -s "$KGSHORTCUTS" "$KGSHORTCUTS_PLASMA"; then
    pass "kglobalshortcutsrc efectivo == plasma (cmp)"
else
    fail "kglobalshortcutsrc efectivo ausente o divergente"
fi
if grep -qx 'ColorScheme=NimbusTahoe' "$KDEGLOBALS" 2>/dev/null; then
    pass "kdeglobals efectivo: ColorScheme=NimbusTahoe"
else
    fail "kdeglobals efectivo sin ColorScheme=NimbusTahoe (tema no se aplica)"
fi

echo "== build-iso / skel =="
if grep -q 'dotfiles/.config/kwinrc' "$BUILD_ISO"; then
    pass "build-iso exige dotfiles/.config/kwinrc"
else
    fail "build-iso no exige dotfiles/.config/kwinrc"
fi
if grep -q 'dotfiles/.config/kdeglobals' "$BUILD_ISO"; then
    pass "build-iso exige dotfiles/.config/kdeglobals"
else
    fail "build-iso no exige dotfiles/.config/kdeglobals"
fi
if grep -q 'cmp -s "$OUT/airootfs/etc/skel/.config/kwinrc"' "$BUILD_ISO"; then
    pass "build-iso verifica kwinrc efectivo en el staging (cmp)"
else
    fail "build-iso no verifica el kwinrc efectivo del staging"
fi
if [ -f "$AUTOSTART" ] && grep -qx 'Exec=/usr/local/bin/nimbus-hide-panel' "$AUTOSTART"; then
    pass "autostart nimbus-hide-panel con Exec canónico"
else
    fail "falta autostart nimbus-hide-panel o su Exec"
fi

echo "== nimbus-installed-setup =="
if grep -q 'dst="$base/.config/kwinrc"' "$SETUP" &&
   grep -q 'install -Dm644 "$src" "$dst"' "$SETUP"; then
    pass "setup copia plasma/kwinrc -> .config/kwinrc si falta"
else
    fail "setup no copia el kwinrc efectivo"
fi
if grep -q 'dst="$base/.config/kdeglobals"' "$SETUP"; then
    pass "setup copia plasma/kdeglobals -> .config/kdeglobals si falta"
else
    fail "setup no copia el kdeglobals efectivo"
fi
if grep -q 'for krc in /etc/skel/.config/kwinrc /etc/skel/.config/plasma/kwinrc' "$SETUP"; then
    pass "setup fija Klassy en kwinrc efectivo y plasma"
else
    fail "setup no fija Klassy en ambos kwinrc"
fi
usermod_n="$(grep -c 'usermod -aG input "\$TARGET_USER"' "$SETUP" 2>/dev/null || true)"
if [ "$usermod_n" = "1" ]; then
    pass "usermod -aG input aparece una sola vez"
else
    fail "usermod -aG input aparece $usermod_n veces (se esperaba 1)"
fi
usermod_line="$(grep -n 'usermod -aG input "\$TARGET_USER"' "$SETUP" | head -1 | cut -d: -f1)"
theme_line="$(grep -n '^THEME_UNIT_DIR=' "$SETUP" | head -1 | cut -d: -f1)"
if [ -n "$usermod_line" ] && [ -n "$theme_line" ] && [ "$usermod_line" -lt "$theme_line" ]; then
    pass "grupo input se aplica fuera/antes del bloque del timer de tema"
else
    fail "usermod sigue condicionado al timer de tema (línea $usermod_line vs $theme_line)"
fi

echo "== nimbus-hide-panel (qdbus6 falso) =="
if [ ! -x "$HIDE" ]; then
    fail "nimbus-hide-panel ausente o sin +x"
else
    T="$(mktemp -d)"
    trap 'rm -rf "$T"' EXIT
    mkdir -p "$T/bin" "$T/home"
    cat >"$T/bin/qdbus6" <<'FAKE'
#!/usr/bin/env bash
# qdbus6 falso: el último argumento es el script de evaluateScript.
last=""
for a in "$@"; do last="$a"; done
case "$last" in
    *'p.hiding = "autohide"'*)
        if [ "${NIMBUS_FAKE_APPLY_RC:-0}" -ne 0 ]; then
            printf 'script error\n' >&2
        else
            printf '%s\n' "${NIMBUS_FAKE_APPLY_OUT:-1}"
        fi
        exit "${NIMBUS_FAKE_APPLY_RC:-0}"
        ;;
    *'p.hiding'*)
        printf '%s\n' "${NIMBUS_FAKE_HIDING:-autohide}"
        ;;
    *'panels().length'*)
        n=0
        [ -f "$NIMBUS_FAKE_STATE" ] && n="$(cat "$NIMBUS_FAKE_STATE")"
        if [ "${n:-0}" -lt "${NIMBUS_FAKE_PANELS_AT:-0}" ]; then
            printf '%s\n' "$((n + 1))" >"$NIMBUS_FAKE_STATE"
            printf '0\n'
        else
            printf '%s\n' "${NIMBUS_FAKE_COUNT:-1}"
        fi
        ;;
    *) printf '0\n' ;;
esac
FAKE
    chmod +x "$T/bin/qdbus6"

    run_hide() { # run_hide <timeout> [env...]
        HOME="$T/home" PATH="$T/bin:$PATH" NIMBUS_HIDE_PANEL_TIMEOUT="$1" \
            NIMBUS_FAKE_STATE="$T/state" env "${@:2}" "$HIDE"
    }
    rm -f "$T/state"
    if run_hide 3 NIMBUS_FAKE_PANELS_AT=2 NIMBUS_FAKE_COUNT=1 >"$T/out1" 2>&1; then
        if grep -q 'OK: 1 panel(es) -> hiding=autohide' "$T/home/.cache/nimbus/hide-panel.log" 2>/dev/null; then
            pass "panel: reintenta hasta panels()>0 y aplica hiding=autohide"
        else
            fail "panel: no loguea el éxito de hiding=autohide"
        fi
    else
        fail "panel: exit != 0 con paneles disponibles ($(tr '\n' '|' <"$T/out1"))"
    fi

    rm -f "$T/state" "$T/home/.cache/nimbus/hide-panel.log"
    if run_hide 1 NIMBUS_FAKE_PANELS_AT=999 NIMBUS_FAKE_COUNT=0 >"$T/out2" 2>&1; then
        grep -q 'AVISO: sin panel que ocultar' "$T/home/.cache/nimbus/hide-panel.log" 2>/dev/null \
            && pass "panel: sin paneles tras timeout -> AVISO y exit 0" \
            || fail "panel: exit 0 sin paneles pero sin AVISO en el log"
    else
        fail "panel: exit != 0 cuando no hay paneles (no debe romper la sesión)"
    fi

    rm -f "$T/state" "$T/home/.cache/nimbus/hide-panel.log"
    if run_hide 1 NIMBUS_FAKE_PANELS_AT=0 NIMBUS_FAKE_COUNT=1 \
        NIMBUS_FAKE_APPLY_RC=1 >"$T/out3" 2>&1; then
        fail "panel: exit 0 aunque evaluateScript falla (falso positivo)"
    else
        grep -q 'ERROR: no se pudo ocultar el panel' "$T/home/.cache/nimbus/hide-panel.log" 2>/dev/null \
            && pass "panel: evaluateScript con error -> ERROR y exit 1" \
            || fail "panel: exit 1 sin ERROR en el log"
    fi

    rm -f "$T/state" "$T/home/.cache/nimbus/hide-panel.log"
    if run_hide 1 NIMBUS_FAKE_PANELS_AT=0 NIMBUS_FAKE_COUNT=1 \
        NIMBUS_FAKE_HIDING=none >"$T/out4" 2>&1; then
        fail "panel: exit 0 aunque hiding sigue en none (falso positivo)"
    else
        grep -q 'hiding real «none»' "$T/home/.cache/nimbus/hide-panel.log" 2>/dev/null \
            && pass "panel: verifica el estado real (hiding=none -> ERROR)" \
            || fail "panel: no registra que hiding sigue en none"
    fi
fi

echo
if [ "$FAILS" = "0" ]; then echo "KWINRC/PANEL VERDE."; exit 0; else echo "KWINRC/PANEL ROJO: $FAILS fallo(s)." >&2; exit 1; fi
