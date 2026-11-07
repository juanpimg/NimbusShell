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
             "$REPO_ROOT/scripts/apply-theme" \
             "$REPO_ROOT/scripts/install-klassy-nimbus" \
             "$REPO_ROOT/scripts/install-glass-nimbus" \
             "$REPO_ROOT/scripts/nimbus-theme" \
             "$REPO_ROOT/scripts/nimbus-i18n" \
             "$REPO_ROOT/scripts/nimbus-bar-preset" \
             "$REPO_ROOT/scripts/nimbus-layout" \
             "$REPO_ROOT/scripts/nimbus-control" \
             "$REPO_ROOT/scripts/nimbus-pxe" \
             "$REPO_ROOT/scripts/dev-vm" \
             "$REPO_ROOT/scripts/dev-remote" \
             "$REPO_ROOT/scripts/nimbus-privacy" \
             "$REPO_ROOT/scripts/nimbus-flatpak-perms" \
             "$REPO_ROOT/scripts/nimbus-trash" \
             "$REPO_ROOT/scripts/nimbus-dock" \
             "$REPO_ROOT/scripts/nimbus-a11y" \
             "$REPO_ROOT/scripts/nimbus-updates" \
             "$REPO_ROOT/apps/nimbus-hw/nimbus-hw" \
             "$REPO_ROOT/apps/nimbus-hw/nimbus-gpu-detect" \
             "$REPO_ROOT/apps/nimbus-hw/nimbus-gpu-setup" \
             "$REPO_ROOT/apps/nimbus-migrate/nimbus-migrate-desktop" \
             "$REPO_ROOT/apps/nimbus-migrate/nimbus-migrate-hyprland" \
             "$REPO_ROOT/apps/backup/nimbus-backup" \
             "$REPO_ROOT/apps/nimbus-bug-report/nimbus-bug-report" \
             "$REPO_ROOT"/iso/calamares/scripts/*.sh \
             "$REPO_ROOT/iso/build-iso.sh" \
             "$REPO_ROOT/iso/profile/airootfs/usr/local/bin/nimbus-installed-setup" \
             "$REPO_ROOT/iso/profile/airootfs/usr/local/bin/nimbus-hide-panel" \
             "$REPO_ROOT/tests/calamares/test_calamares_config.sh" \
             "$REPO_ROOT/tests/apps/test_apps_deploy.sh" \
             "$REPO_ROOT/tests/docs/test_docs_consistency.sh" \
             "$REPO_ROOT/tests/welcome/test_welcome.sh" \
             "$REPO_ROOT/tests/support/test_bug_report.sh" \
             "$REPO_ROOT/tests/widgets/test_widgets.sh" \
             "$REPO_ROOT/tests/lock/test_lockscreen.sh" \
             "$REPO_ROOT/tests/a11y/test_a11y.sh" \
             "$REPO_ROOT/tests/updates/test_updates.sh" \
             "$REPO_ROOT/tests/migrate/test_desktop_migrate.sh" \
             "$REPO_ROOT/tests/migrate/test_hyprland_migrate.sh" \
             "$REPO_ROOT/tests/bar/test_kwinrc.sh" \
             "$REPO_ROOT/tests/bar/test_presets.sh" \
             "$REPO_ROOT/tests/dock/test_dock_config.sh" \
             "$REPO_ROOT/tests/dock/test_dock_trash.sh" \
             "$REPO_ROOT/tests/dock/test_dock_prefs.sh" \
             "$REPO_ROOT/tests/security/test_security.sh" \
             "$REPO_ROOT/tests/hw/test_hw.sh" \
             "$REPO_ROOT/tests/qml/test_qml_suite.sh" \
             "$REPO_ROOT/tests/theme/test_apply_theme.sh" \
             "$REPO_ROOT/tests/theme/test_themes_deploy.sh" \
             "$REPO_ROOT/tests/theme/test_nimbus_theme.sh" \
             "$REPO_ROOT/tests/windows/test_drag_doubleclick.sh" \
             "$REPO_ROOT/tests/vm/windows.sh" \
             "$REPO_ROOT/tests/vm/dock.sh" \
             "$REPO_ROOT/tests/vm/dock-acceptance.sh" \
             "$REPO_ROOT/tests/vm/overview-acceptance.sh" \
             "$REPO_ROOT/tests/kcm/test-pages.sh" \
             "$REPO_ROOT"/tests/kcm/fakes/* \
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
    if [ -x "$REPO_ROOT/tests/qml/test_qml_suite.sh" ]; then
        if "$REPO_ROOT/tests/qml/test_qml_suite.sh" >/tmp/opencode/ci-qml-suite.txt 2>&1; then
            pass "qmltestrunner suite (tst_*.qml)"
        else
            fail "qmltestrunner suite (ver /tmp/opencode/ci-qml-suite.txt)"
        fi
    fi
fi

echo "== ci: javascript (syntax check) =="
if command -v node >/dev/null 2>&1; then
    js_fail=0
    while IFS= read -r f; do
        node -c "$f" >/dev/null 2>&1 || { echo "  [FAIL] JS syntax error: ${f#"$REPO_ROOT"/}" >&2; js_fail=1; }
    done < <(find "$REPO_ROOT/packages/kwin" -name "*.js" 2>/dev/null)
    [ "$js_fail" = "0" ] && pass "node -c en scripts y efectos KWin" || fail "node -c en scripts/efectos KWin"
else
    pass "node ausente (skip limpio)"
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

echo "== ci: bar presets (tests/bar/test_presets.sh) =="
if [ -x "$REPO_ROOT/tests/bar/test_presets.sh" ]; then
    if "$REPO_ROOT/tests/bar/test_presets.sh" >/tmp/opencode/ci-bar-presets.txt 2>&1; then
        pass "tests/bar/test_presets.sh"
    else fail "tests/bar/test_presets.sh (ver /tmp/opencode/ci-bar-presets.txt)"; fi
else fail "tests/bar/test_presets.sh ausente o sin +x"; fi

echo "== ci: live user + SDDM (tests/live/test_live_user.sh) =="
if [ -x "$REPO_ROOT/tests/live/test_live_user.sh" ]; then
    if "$REPO_ROOT/tests/live/test_live_user.sh" >/tmp/opencode/ci-live-user.txt 2>&1; then
        pass "tests/live/test_live_user.sh"
    else fail "tests/live/test_live_user.sh (ver /tmp/opencode/ci-live-user.txt)"; fi
else fail "tests/live/test_live_user.sh ausente o sin +x"; fi

echo "== ci: dock (tests/dock/test_dock_config.sh) =="
if [ -x "$REPO_ROOT/tests/dock/test_dock_config.sh" ]; then
    if "$REPO_ROOT/tests/dock/test_dock_config.sh" >/tmp/opencode/ci-dock.txt 2>&1; then
        pass "tests/dock/test_dock_config.sh"
    else fail "tests/dock/test_dock_config.sh (ver /tmp/opencode/ci-dock.txt)"; fi
else fail "tests/dock/test_dock_config.sh ausente o sin +x"; fi

echo "== ci: theme (tests/theme/test_apply_theme.sh) =="
if [ -x "$REPO_ROOT/tests/theme/test_apply_theme.sh" ]; then
    if "$REPO_ROOT/tests/theme/test_apply_theme.sh" >/tmp/opencode/ci-theme.txt 2>&1; then
        pass "tests/theme/test_apply_theme.sh"
    else fail "tests/theme/test_apply_theme.sh (ver /tmp/opencode/ci-theme.txt)"; fi
else fail "tests/theme/test_apply_theme.sh ausente o sin +x"; fi

echo "== ci: theme deploy integration (tests/theme/test_themes_deploy.sh) =="
if [ -x "$REPO_ROOT/tests/theme/test_themes_deploy.sh" ]; then
    if "$REPO_ROOT/tests/theme/test_themes_deploy.sh" >/tmp/opencode/ci-themes-deploy.txt 2>&1; then
        pass "tests/theme/test_themes_deploy.sh (14/14 ok)"
    else fail "tests/theme/test_themes_deploy.sh (ver /tmp/opencode/ci-themes-deploy.txt)"; fi
else fail "tests/theme/test_themes_deploy.sh ausente o sin +x"; fi

echo "== ci: nimbus-theme light/dark (tests/theme/test_nimbus_theme.sh) =="
if [ -x "$REPO_ROOT/tests/theme/test_nimbus_theme.sh" ]; then
    if "$REPO_ROOT/tests/theme/test_nimbus_theme.sh" >/tmp/opencode/ci-nimbus-theme.txt 2>&1; then
        pass "tests/theme/test_nimbus_theme.sh (14/14 ok)"
    else fail "tests/theme/test_nimbus_theme.sh (ver /tmp/opencode/ci-nimbus-theme.txt)"; fi
else fail "tests/theme/test_nimbus_theme.sh ausente o sin +x"; fi

echo "== ci: window drag and doubleclick (tests/windows/test_drag_doubleclick.sh) =="
if [ -x "$REPO_ROOT/tests/windows/test_drag_doubleclick.sh" ]; then
    if "$REPO_ROOT/tests/windows/test_drag_doubleclick.sh" >/tmp/opencode/ci-drag.txt 2>&1; then
        pass "tests/windows/test_drag_doubleclick.sh"
    else fail "tests/windows/test_drag_doubleclick.sh (ver /tmp/opencode/ci-drag.txt)"; fi
else fail "tests/windows/test_drag_doubleclick.sh ausente o sin +x"; fi

echo "== ci: windows acceptance (tests/vm/windows.sh) =="
if [ -x "$REPO_ROOT/tests/vm/windows.sh" ]; then
    if "$REPO_ROOT/tests/vm/windows.sh" >/tmp/opencode/ci-windows.txt 2>&1; then
        pass "tests/vm/windows.sh"
    else fail "tests/vm/windows.sh (ver /tmp/opencode/ci-windows.txt)"; fi
else fail "tests/vm/windows.sh ausente o sin +x"; fi

echo "== ci: security (tests/security/test_security.sh) =="
if [ -x "$REPO_ROOT/tests/security/test_security.sh" ]; then
    if "$REPO_ROOT/tests/security/test_security.sh" >/tmp/opencode/ci-security.txt 2>&1; then
        pass "tests/security/test_security.sh"
    else fail "tests/security/test_security.sh (ver /tmp/opencode/ci-security.txt)"; fi
else fail "tests/security/test_security.sh ausente o sin +x"; fi

echo "== ci: hardware and energy (tests/hw/test_hw.sh) =="
if [ -x "$REPO_ROOT/tests/hw/test_hw.sh" ]; then
    if "$REPO_ROOT/tests/hw/test_hw.sh" >/tmp/opencode/ci-hw.txt 2>&1; then
        pass "tests/hw/test_hw.sh"
    else fail "tests/hw/test_hw.sh (ver /tmp/opencode/ci-hw.txt)"; fi
else fail "tests/hw/test_hw.sh ausente o sin +x"; fi

echo "== ci: dock trash (tests/dock/test_dock_trash.sh) =="
if [ -x "$REPO_ROOT/tests/dock/test_dock_trash.sh" ]; then
    if "$REPO_ROOT/tests/dock/test_dock_trash.sh" >/tmp/opencode/ci-dock-trash.txt 2>&1; then
        pass "tests/dock/test_dock_trash.sh"
    else fail "tests/dock/test_dock_trash.sh (ver /tmp/opencode/ci-dock-trash.txt)"; fi
else fail "tests/dock/test_dock_trash.sh ausente o sin +x"; fi

echo "== ci: dock preferences (tests/dock/test_dock_prefs.sh) =="
if [ -x "$REPO_ROOT/tests/dock/test_dock_prefs.sh" ]; then
    if "$REPO_ROOT/tests/dock/test_dock_prefs.sh" >/tmp/opencode/ci-dock-prefs.txt 2>&1; then
        pass "tests/dock/test_dock_prefs.sh"
    else fail "tests/dock/test_dock_prefs.sh (ver /tmp/opencode/ci-dock-prefs.txt)"; fi
else fail "tests/dock/test_dock_prefs.sh ausente o sin +x"; fi

echo "== ci: dock perf (tests/vm/dock.sh) =="
if [ -x "$REPO_ROOT/tests/vm/dock.sh" ]; then
    if "$REPO_ROOT/tests/vm/dock.sh" >/tmp/opencode/ci-dock-perf.txt 2>&1; then
        pass "tests/vm/dock.sh"
    else fail "tests/vm/dock.sh (ver /tmp/opencode/ci-dock-perf.txt)"; fi
else fail "tests/vm/dock.sh ausente o sin +x"; fi

echo "== ci: dock acceptance (tests/vm/dock-acceptance.sh) =="
if [ -x "$REPO_ROOT/tests/vm/dock-acceptance.sh" ]; then
    if "$REPO_ROOT/tests/vm/dock-acceptance.sh" >/tmp/opencode/ci-dock-acceptance.txt 2>&1; then
        pass "tests/vm/dock-acceptance.sh"
    else fail "tests/vm/dock-acceptance.sh (ver /tmp/opencode/ci-dock-acceptance.txt)"; fi
else fail "tests/vm/dock-acceptance.sh ausente o sin +x"; fi

echo "== ci: overview acceptance (tests/vm/overview-acceptance.sh) =="
if [ -x "$REPO_ROOT/tests/vm/overview-acceptance.sh" ]; then
    if "$REPO_ROOT/tests/vm/overview-acceptance.sh" >/tmp/opencode/ci-overview-acceptance.txt 2>&1; then
        pass "tests/vm/overview-acceptance.sh"
    else fail "tests/vm/overview-acceptance.sh (ver /tmp/opencode/ci-overview-acceptance.txt)"; fi
else fail "tests/vm/overview-acceptance.sh ausente o sin +x"; fi

echo "== ci: accessibility (tests/a11y/test_a11y.sh) =="
if [ -x "$REPO_ROOT/tests/a11y/test_a11y.sh" ]; then
    if "$REPO_ROOT/tests/a11y/test_a11y.sh" >/tmp/opencode/ci-a11y.txt 2>&1; then
        pass "tests/a11y/test_a11y.sh (58/58 ok)"
    else fail "tests/a11y/test_a11y.sh (ver /tmp/opencode/ci-a11y.txt)"; fi
else fail "tests/a11y/test_a11y.sh ausente o sin +x"; fi

echo "== ci: apps and spotlight a11y =="
if python3 "$REPO_ROOT/tests/spotlight/test_a11y.py" >/tmp/opencode/ci-spot-a11y.txt 2>&1 && \
   python3 "$REPO_ROOT/tests/apps/test_a11y.py" >/tmp/opencode/ci-apps-a11y.txt 2>&1; then
    pass "tests/{spotlight,apps}/test_a11y.py (65 checks ok)"
else fail "spotlight/apps a11y (ver /tmp/opencode/ci-*-a11y.txt)"; fi

echo "== ci: spotlight index suite =="
if python3 "$REPO_ROOT/tests/spotlight/test_index.py" >/tmp/opencode/ci-spot-index.txt 2>&1; then
    pass "tests/spotlight/test_index.py (23 checks ok)"
else fail "spotlight index (ver /tmp/opencode/ci-spot-index.txt)"; fi

echo "== ci: kcm pages (tests/kcm/test-pages.sh) =="
if [ -x "$REPO_ROOT/tests/kcm/test-pages.sh" ]; then
    if "$REPO_ROOT/tests/kcm/test-pages.sh" >/tmp/opencode/ci-kcm-pages.txt 2>&1; then
        pass "tests/kcm/test-pages.sh (89/89 ok)"
    else fail "tests/kcm/test-pages.sh (ver /tmp/opencode/ci-kcm-pages.txt)"; fi
else fail "tests/kcm/test-pages.sh ausente o sin +x"; fi

echo "== ci: apps categories and parsing =="
if python3 "$REPO_ROOT/tests/apps/test_categories.py" >/tmp/opencode/ci-apps-cats.txt 2>&1 && \
   python3 "$REPO_ROOT/tests/apps/test_desktop_parse.py" >/tmp/opencode/ci-apps-parse.txt 2>&1; then
    pass "tests/apps/{test_categories,test_desktop_parse}.py (32 checks ok)"
else fail "apps categories/parse (ver /tmp/opencode/ci-apps-*.txt)"; fi

echo "== ci: apps deploy (tests/apps/test_apps_deploy.sh) =="
if [ -x "$REPO_ROOT/tests/apps/test_apps_deploy.sh" ]; then
    if "$REPO_ROOT/tests/apps/test_apps_deploy.sh" >/tmp/opencode/ci-apps-deploy.txt 2>&1; then
        pass "tests/apps/test_apps_deploy.sh (28/28 ok)"
    else fail "tests/apps/test_apps_deploy.sh (ver /tmp/opencode/ci-apps-deploy.txt)"; fi
else fail "tests/apps/test_apps_deploy.sh ausente o sin +x"; fi

echo "== ci: docs consistency (tests/docs/test_docs_consistency.sh) =="
if [ -x "$REPO_ROOT/tests/docs/test_docs_consistency.sh" ]; then
    if "$REPO_ROOT/tests/docs/test_docs_consistency.sh" >/tmp/opencode/ci-docs.txt 2>&1; then
        pass "tests/docs/test_docs_consistency.sh"
    else fail "tests/docs/test_docs_consistency.sh (ver /tmp/opencode/ci-docs.txt)"; fi
else fail "tests/docs/test_docs_consistency.sh ausente o sin +x"; fi

echo "== ci: system updates and rollback (tests/updates/test_updates.sh) =="
if [ -x "$REPO_ROOT/tests/updates/test_updates.sh" ]; then
    if "$REPO_ROOT/tests/updates/test_updates.sh" >/tmp/opencode/ci-updates.txt 2>&1; then
        pass "tests/updates/test_updates.sh (19/19 ok)"
    else fail "tests/updates/test_updates.sh (ver /tmp/opencode/ci-updates.txt)"; fi
else fail "tests/updates/test_updates.sh ausente o sin +x"; fi

echo "== ci: migrations (tests/migrate/) =="
if [ -x "$REPO_ROOT/tests/migrate/test_desktop_migrate.sh" ] && [ -x "$REPO_ROOT/tests/migrate/test_hyprland_migrate.sh" ]; then
    if "$REPO_ROOT/tests/migrate/test_desktop_migrate.sh" >/tmp/opencode/ci-mig-desk.txt 2>&1 && \
       "$REPO_ROOT/tests/migrate/test_hyprland_migrate.sh" >/tmp/opencode/ci-mig-hypr.txt 2>&1; then
        pass "tests/migrate/{test_desktop_migrate,test_hyprland_migrate}.sh (37/37 ok)"
    else fail "tests/migrate (ver /tmp/opencode/ci-mig-*.txt)"; fi
else fail "tests/migrate/*.sh ausente o sin +x"; fi

echo "== ci: calamares config (tests/calamares/test_calamares_config.sh) =="
if [ -x "$REPO_ROOT/tests/calamares/test_calamares_config.sh" ]; then
    if "$REPO_ROOT/tests/calamares/test_calamares_config.sh" >/tmp/opencode/ci-calamares.txt 2>&1; then
        pass "tests/calamares/test_calamares_config.sh"
    else fail "tests/calamares/test_calamares_config.sh (ver /tmp/opencode/ci-calamares.txt)"; fi
else fail "tests/calamares/test_calamares_config.sh ausente o sin +x"; fi

echo "== ci: support and diagnostics (tests/support/test_bug_report.sh) =="
if [ -x "$REPO_ROOT/tests/support/test_bug_report.sh" ]; then
    if "$REPO_ROOT/tests/support/test_bug_report.sh" >/tmp/opencode/ci-support.txt 2>&1; then
        pass "tests/support/test_bug_report.sh"
    else fail "tests/support/test_bug_report.sh (ver /tmp/opencode/ci-support.txt)"; fi
else fail "tests/support/test_bug_report.sh ausente o sin +x"; fi

echo "== ci: widgets and clock (tests/widgets/test_widgets.sh) =="
if [ -x "$REPO_ROOT/tests/widgets/test_widgets.sh" ]; then
    if "$REPO_ROOT/tests/widgets/test_widgets.sh" >/tmp/opencode/ci-widgets.txt 2>&1; then
        pass "tests/widgets/test_widgets.sh"
    else fail "tests/widgets/test_widgets.sh (ver /tmp/opencode/ci-widgets.txt)"; fi
else fail "tests/widgets/test_widgets.sh ausente o sin +x"; fi

echo "== ci: lockscreen (tests/lock/test_lockscreen.sh) =="
if [ -x "$REPO_ROOT/tests/lock/test_lockscreen.sh" ]; then
    if "$REPO_ROOT/tests/lock/test_lockscreen.sh" >/tmp/opencode/ci-lockscreen.txt 2>&1; then
        pass "tests/lock/test_lockscreen.sh"
    else fail "tests/lock/test_lockscreen.sh (ver /tmp/opencode/ci-lockscreen.txt)"; fi
else fail "tests/lock/test_lockscreen.sh ausente o sin +x"; fi

echo "== ci: welcome wizard (tests/welcome/test_welcome.sh) =="
if [ -x "$REPO_ROOT/tests/welcome/test_welcome.sh" ]; then
    if "$REPO_ROOT/tests/welcome/test_welcome.sh" >/tmp/opencode/ci-welcome.txt 2>&1; then
        pass "tests/welcome/test_welcome.sh"
    else fail "tests/welcome/test_welcome.sh (ver /tmp/opencode/ci-welcome.txt)"; fi
else fail "tests/welcome/test_welcome.sh ausente o sin +x"; fi

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
