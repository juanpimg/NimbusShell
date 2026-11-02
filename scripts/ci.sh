#!/bin/bash
# NimbusShell CI local — lint y verificaciones sin sudo, sin red, sin escritura.
# Uso: scripts/ci.sh [--self-test]
#   --self-test: verifica que el lint detecta un fichero con error (y limpia).
# Salida [OK]/[FAIL] por paso; exit 0 verde, 1 rojo.
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FAILS=0

pass() { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1" >&2; FAILS=$((FAILS + 1)); }

SELF_TEST=0
for arg in "$@"; do
    case "$arg" in
        --self-test) SELF_TEST=1 ;;
        -h|--help) echo "Uso: scripts/ci.sh [--self-test]"; exit 0 ;;
        *) echo "ERROR: argumento desconocido: $arg (ver --help)" >&2; exit 2 ;;
    esac
done

sh_files() { # stdout: scripts bash del perfil activo (nunca legacy/)
    for f in "$REPO_ROOT/install.sh" "$REPO_ROOT"/lib/*.sh "$REPO_ROOT"/scripts/*.sh \
             "$REPO_ROOT/scripts/install-klassy-nimbus" \
             "$REPO_ROOT"/iso/calamares/scripts/*.sh \
             "$REPO_ROOT/iso/build-iso.sh" \
             "$REPO_ROOT/iso/profile/airootfs/usr/local/bin/nimbus-installed-setup" \
             "$REPO_ROOT/iso/profile/airootfs/usr/local/bin/nimbus-hide-panel" \
             "$REPO_ROOT/tests/bar/test_kwinrc.sh" \
             "$REPO_ROOT/legacy/hyprland/install.sh"; do
        [ -f "$f" ] && printf '%s\n' "$f"
    done
}

echo "== ci: bash -n =="
while IFS= read -r f; do
    if bash -n "$f" 2>/tmp/opencode/ci-err.txt; then pass "bash -n ${f#"$REPO_ROOT"/}";
    else fail "bash -n ${f#"$REPO_ROOT"/} ($(cat /tmp/opencode/ci-err.txt))"; fi
done < <(sh_files)

echo "== ci: shellcheck -S warning =="
if ! command -v shellcheck >/dev/null 2>&1; then
    fail "shellcheck ausente (instálalo: pacman -S shellcheck)"
else
    while IFS= read -r f; do
        if shellcheck -S warning "$f" 2>/tmp/opencode/ci-err.txt; then pass "shellcheck ${f#"$REPO_ROOT"/}";
        else fail "shellcheck ${f#"$REPO_ROOT"/} ($(head -3 /tmp/opencode/ci-err.txt | tr '\n' '|'))"; fi
    done < <(sh_files)
fi

echo "== ci: qml (packages/, apps/) =="
qml_files="$(find "$REPO_ROOT/packages" "$REPO_ROOT/apps" -name '*.qml' 2>/dev/null || true)"
if [ -z "$qml_files" ]; then
    pass "sin .qml fuera de legacy (skip limpio; legacy/ no se linta)"
else
    if ! command -v qmllint >/dev/null 2>&1; then
        fail "hay .qml pero falta qmllint"
    else
        qfail=0
        while IFS= read -r f; do
            qmllint "$f" >/dev/null 2>&1 || { echo "  [FAIL] qmllint ${f#"$REPO_ROOT"/}" >&2; qfail=1; }
        done < <(printf '%s\n' "$qml_files")
        [ "$qfail" = "0" ] && pass "qmllint" || fail "qmllint"
    fi
    QMLFORMAT="/usr/lib/qt6/bin/qmlformat"
    [ -x "$QMLFORMAT" ] || QMLFORMAT="$(command -v qmlformat || true)"
    if [ -z "$QMLFORMAT" ]; then
        fail "hay .qml pero falta qmlformat"
    else
        ffail=0
        while IFS= read -r f; do
            fmt_tmp="$(mktemp)"
            if ! "$QMLFORMAT" "$f" >"$fmt_tmp" 2>/dev/null; then
                echo "  [FAIL] qmlformat ${f#"$REPO_ROOT"/}" >&2; ffail=1
            elif ! diff -q "$f" "$fmt_tmp" >/dev/null 2>&1; then
                echo "  [FAIL] qmlformat ${f#"$REPO_ROOT"/} (no formateado)" >&2; ffail=1
            fi
            rm -f "$fmt_tmp"
        done < <(printf '%s\n' "$qml_files")
        [ "$ffail" = "0" ] && pass "qmlformat (Qt6, idempotente)" || fail "qmlformat (Qt6, idempotente)"
    fi
fi

echo "== ci: json =="
json_files="$(find "$REPO_ROOT" -path "$REPO_ROOT/.git" -prune -o -path "$REPO_ROOT/legacy" -prune -o \
    \( -name 'metadata.json' -o -name 'settings*.json' \) -print 2>/dev/null || true)"
if [ -z "$json_files" ]; then
    pass "sin JSON fuera de legacy (skip limpio)"
elif ! command -v python3 >/dev/null 2>&1; then
    fail "hay JSON pero falta python3"
else
    jfail=0
    while IFS= read -r f; do
        python3 -m json.tool "$f" >/dev/null 2>&1 || { echo "  [FAIL] JSON inválido: ${f#"$REPO_ROOT"/}" >&2; jfail=1; }
    done < <(printf '%s\n' "$json_files")
    [ "$jfail" = "0" ] && pass "JSON válido" || fail "JSON válido"
fi

echo "== ci: desktop files =="
desk_files="$(find "$REPO_ROOT" -path "$REPO_ROOT/.git" -prune -o -path "$REPO_ROOT/legacy" -prune -o \
    -name '*.desktop' -print 2>/dev/null || true)"
if [ -z "$desk_files" ]; then
    pass "sin .desktop fuera de legacy (skip limpio)"
elif ! command -v desktop-file-validate >/dev/null 2>&1; then
    fail "hay .desktop pero falta desktop-file-validate"
else
    dfail=0
    while IFS= read -r f; do
        # SDDM y otros metadata.desktop no son entradas freedesktop: solo se
        # valida lo que declara [Desktop Entry] (apps, autostart, servicios).
        grep -q '^\[Desktop Entry\]' "$f" || continue
        desktop-file-validate "$f" >/dev/null 2>&1 || { echo "  [FAIL] .desktop inválido: ${f#"$REPO_ROOT"/}" >&2; dfail=1; }
    done < <(printf '%s\n' "$desk_files")
    [ "$dfail" = "0" ] && pass ".desktop válidos" || fail ".desktop válidos"
fi

echo "== ci: tests del ledger =="
if [ -x "$REPO_ROOT/tests/progress/test_progress.sh" ]; then
    if "$REPO_ROOT/tests/progress/test_progress.sh" >/tmp/opencode/ci-progress.txt 2>&1; then
        pass "tests/progress/test_progress.sh"
    else fail "tests/progress/test_progress.sh (ver /tmp/opencode/ci-progress.txt)"; fi
else fail "tests/progress/test_progress.sh ausente o sin +x"; fi

echo "== ci: ledger de progreso =="
if prog_out="$("$REPO_ROOT/scripts/nimbus-progress" 2>&1)"; then
    total_line="$(printf '%s\n' "$prog_out" | grep -E '^Total: [0-9]+/112' || true)"
    if [ -n "$total_line" ]; then pass "nimbus-progress ($total_line)";
    else fail "nimbus-progress sin línea Total: X/112 parseable"; fi
else fail "scripts/nimbus-progress exit distinto de 0"; fi

echo "== ci: i18n (nimbus-i18n --check, solo lectura) =="
if [ -x "$REPO_ROOT/scripts/nimbus-i18n" ]; then
    if "$REPO_ROOT/scripts/nimbus-i18n" --check >/tmp/opencode/ci-i18n.txt 2>&1; then
        pass "nimbus-i18n --check ($(cat /tmp/opencode/ci-i18n.txt))"
    else fail "nimbus-i18n --check (ver /tmp/opencode/ci-i18n.txt)"; fi
    if [ -x "$REPO_ROOT/tests/i18n/test_i18n.sh" ]; then
        if "$REPO_ROOT/tests/i18n/test_i18n.sh" >/tmp/opencode/ci-i18n-test.txt 2>&1; then
            pass "tests/i18n/test_i18n.sh"
        else fail "tests/i18n/test_i18n.sh (ver /tmp/opencode/ci-i18n-test.txt)"; fi
    else fail "tests/i18n/test_i18n.sh ausente o sin +x"; fi
else fail "scripts/nimbus-i18n ausente o sin +x"; fi

echo "== ci: kwinrc efectivo + panel (tests/bar/test_kwinrc.sh) =="
if cmp -s "$REPO_ROOT/dotfiles/.config/kwinrc" "$REPO_ROOT/dotfiles/.config/plasma/kwinrc"; then
    pass "kwinrc efectivo == plasma/kwinrc (cmp)"
else fail "kwinrc efectivo y plasma/kwinrc divergen (cmp)"; fi
if [ -x "$REPO_ROOT/tests/bar/test_kwinrc.sh" ]; then
    if "$REPO_ROOT/tests/bar/test_kwinrc.sh" >/tmp/opencode/ci-kwinrc.txt 2>&1; then
        pass "tests/bar/test_kwinrc.sh"
    else fail "tests/bar/test_kwinrc.sh (ver /tmp/opencode/ci-kwinrc.txt)"; fi
else fail "tests/bar/test_kwinrc.sh ausente o sin +x"; fi

echo "== ci: install.sh --check (solo lectura) =="
"$REPO_ROOT/install.sh" --check >/tmp/opencode/ci-check.txt 2>&1
rc=$?
if [ "$rc" = "0" ] || [ "$rc" = "1" ]; then
    pass "install.sh --check exit $rc (0 verde, 1 drift esperado en host)"
else fail "install.sh --check exit $rc (se esperaba 0 o 1)"; fi

echo "== ci: packaging (PKGBUILD, sin instalar nada) =="
pkgbuilds="$(find "$REPO_ROOT/packaging" -maxdepth 2 -name 'PKGBUILD' 2>/dev/null || true)"
if [ -z "$pkgbuilds" ]; then
    pass "sin packaging/*/PKGBUILD (skip limpio)"
else
    while IFS= read -r f; do
        if bash -n "$f" 2>/tmp/opencode/ci-err.txt; then pass "bash -n ${f#"$REPO_ROOT"/}";
        else fail "bash -n ${f#"$REPO_ROOT"/} ($(cat /tmp/opencode/ci-err.txt))"; fi
    done < <(printf '%s\n' "$pkgbuilds")
    if ! command -v makepkg >/dev/null 2>&1; then
        pass "makepkg ausente (skip limpio: sin --printsrcinfo)"
    else
        while IFS= read -r f; do
            if (cd "$(dirname "$f")" && makepkg --printsrcinfo >/dev/null 2>/tmp/opencode/ci-err.txt); then
                pass "makepkg --printsrcinfo ${f#"$REPO_ROOT"/}"
            else fail "makepkg --printsrcinfo ${f#"$REPO_ROOT"/} ($(head -3 /tmp/opencode/ci-err.txt | tr '\n' '|'))"; fi
        done < <(printf '%s\n' "$pkgbuilds")
    fi
fi

if [ "$SELF_TEST" = "1" ]; then
    echo "== ci: --self-test (el lint debe fallar con un fichero roto) =="
    printf '#!/bin/bash\necho "$var_sin_definir"\n' > /tmp/ci-bad.sh
    if ! command -v shellcheck >/dev/null 2>&1; then
        fail "--self-test sin shellcheck (no se puede demostrar detección)"
    elif shellcheck -S warning /tmp/ci-bad.sh >/dev/null 2>&1; then
        fail "--self-test: shellcheck NO detectó el error inyectado (SC2154 esperado)"
    else
        pass "--self-test: shellcheck detecta el error inyectado"
    fi
    rm -f /tmp/ci-bad.sh
    [ -e /tmp/ci-bad.sh ] && fail "--self-test no limpió /tmp/ci-bad.sh" || pass "--self-test limpió /tmp/ci-bad.sh"
fi

echo
if [ "$FAILS" = "0" ]; then echo "CI VERDE."; exit 0; else echo "CI ROJO: $FAILS paso(s) en [FAIL]." >&2; exit 1; fi
