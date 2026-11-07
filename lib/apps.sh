#!/bin/bash
# lib/apps.sh — apps Nimbus (F9): scripts de sistema y binarios GUI.
# Los scripts sin compilación (hw, migración, backup, bug-report) se despliegan
# a ~/.local/bin. Los binarios GUI (nimbus-bar, about, apps, clock, help,
# missioncontrol, spotlight, welcome, wallpaper) los compila la ISO con
# iso/build-iso.sh o scripts/dev-remote; aquí solo se verifican.

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
APPS_BIN_DIR="${APPS_BIN_DIR:-${XDG_BIN_HOME:-$HOME/.local/bin}}"
APPS_DESKTOP_DIR="${APPS_DESKTOP_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/applications}"

apps_shell_scripts() { # stdout: rutas relativas al repo
    printf '%s\n' \
        "apps/nimbus-hw/nimbus-hw" \
        "apps/nimbus-hw/nimbus-gpu-detect" \
        "apps/nimbus-hw/nimbus-gpu-setup" \
        "apps/nimbus-migrate/nimbus-migrate-desktop" \
        "apps/nimbus-migrate/nimbus-migrate-hyprland" \
        "apps/backup/nimbus-backup" \
        "apps/nimbus-bug-report/nimbus-bug-report"
}

apps_user_tools() { # stdout: scripts de usuario (no dev) a ~/.local/bin
    printf '%s\n' \
        "scripts/nimbus-theme" \
        "scripts/apply-theme" \
        "scripts/nimbus-dock" \
        "scripts/nimbus-trash" \
        "scripts/nimbus-updates" \
        "scripts/nimbus-a11y" \
        "scripts/nimbus-layout" \
        "scripts/nimbus-keys" \
        "scripts/nimbus-privacy" \
        "scripts/nimbus-flatpak-perms" \
        "scripts/nimbus-bar-preset" \
        "scripts/nimbus-control"
}

apps_gui_map() { # stdout: "binario|desktop relativo"
    printf '%s\n' \
        "nimbus-about|apps/nimbus-about/org.nimbus.about.desktop" \
        "nimbus-apps|apps/nimbus-apps/org.nimbus.Apps.desktop" \
        "nimbus-clock|apps/nimbus-clock/org.nimbus.clock.desktop" \
        "nimbus-help|apps/nimbus-help/org.nimbus.help.desktop" \
        "nimbus-missioncontrol|apps/nimbus-missioncontrol/org.nimbus.missioncontrol.desktop" \
        "nimbus-spotlight|apps/nimbus-spotlight/org.nimbus.spotlight.desktop" \
        "nimbus-welcome|apps/nimbus-welcome/org.nimbus.welcome.desktop"
}

apps_gui_bin() { # $1=binario -> 0 si existe en PATH o /usr/local/bin
    command -v "$1" >/dev/null 2>&1 || [ -x "/usr/local/bin/$1" ]
}

apps_script_installed() { # $1=nombre -> stdout: ruta instalada (usuario o sistema)
    local name="$1" d
    for d in "$APPS_BIN_DIR" /usr/local/bin /usr/bin; do
        if [ -x "$d/$name" ]; then printf '%s\n' "$d/$name"; return 0; fi
    done
    return 1
}

apps_desktop_installed() { # $1=nombre.desktop -> stdout: ruta instalada
    local name="$1" d
    for d in "$APPS_DESKTOP_DIR" /usr/share/applications; do
        if [ -f "$d/$name" ]; then printf '%s\n' "$d/$name"; return 0; fi
    done
    return 1
}

apps_deploy() {
    echo "-- apps de sistema -> $APPS_BIN_DIR..."
    mkdir -p "$APPS_BIN_DIR" "$APPS_DESKTOP_DIR" \
        || { echo "ERROR: no se pudo crear $APPS_BIN_DIR o $APPS_DESKTOP_DIR" >&2; return 1; }

    local rel src dst n=0
    while IFS= read -r rel; do
        src="$REPO_ROOT/$rel"
        dst="$APPS_BIN_DIR/$(basename "$rel")"
        if [ ! -f "$src" ]; then
            echo "ERROR: falta $rel (repo incompleto)" >&2
            return 1
        fi
        install -m755 "$src" "$dst" \
            || { echo "ERROR: no se pudo instalar $rel en $dst" >&2; return 1; }
        n=$((n + 1))
    done < <(apps_shell_scripts)
    nimbus_ok "$n scripts de apps instalados en $APPS_BIN_DIR"

    # Herramientas de usuario (tema, dock, updates, layout, privacidad...).
    local n_tools=0
    while IFS= read -r rel; do
        src="$REPO_ROOT/$rel"
        dst="$APPS_BIN_DIR/$(basename "$rel")"
        if [ ! -f "$src" ]; then
            echo "ERROR: falta $rel (repo incompleto)" >&2
            return 1
        fi
        install -m755 "$src" "$dst" \
            || { echo "ERROR: no se pudo instalar $rel en $dst" >&2; return 1; }
        n_tools=$((n_tools + 1))
    done < <(apps_user_tools)
    nimbus_ok "$n_tools herramientas instaladas en $APPS_BIN_DIR"

    # Recursos que consumen esas herramientas desde rutas de usuario.
    local res="${XDG_DATA_HOME:-$HOME/.local/share}/nimbus"
    mkdir -p "$res/bar" "$res/dock" \
        || { echo "ERROR: no se pudo crear $res" >&2; return 1; }
    if [ -d "$REPO_ROOT/packages/shell/nimbus-bar/presets" ]; then
        mkdir -p "$res/bar/presets"
        cp -a "$REPO_ROOT/packages/shell/nimbus-bar/presets/." "$res/bar/presets/" || return 1
        cp -a "$REPO_ROOT/packages/shell/nimbus-bar/pins.txt" "$res/bar/" || return 1
    fi
    if [ -f "$REPO_ROOT/packages/dock/kremarc-nimbus" ]; then
        cp -a "$REPO_ROOT/packages/dock/kremarc-nimbus" "$res/dock/" || return 1
    fi

    # Timer de tema automático (idempotente; en TTY sin bus solo avisa).
    if [ "${NIMBUS_NO_LIVE:-0}" != "1" ] && [ -x "$APPS_BIN_DIR/nimbus-theme" ]; then
        "$APPS_BIN_DIR/nimbus-theme" --auto enable >/dev/null 2>&1 \
            || nimbus_info "  [PENDIENTE] activa el tema automático: nimbus-theme --auto enable"
    fi

    # Desktop del reportador de bugs (app de script, siempre disponible).
    install -m644 "$REPO_ROOT/apps/nimbus-bug-report/org.nimbus.bugreport.desktop" \
        "$APPS_DESKTOP_DIR/org.nimbus.bugreport.desktop" \
        || { echo "ERROR: no se pudo instalar org.nimbus.bugreport.desktop" >&2; return 1; }

    # Desktop de las apps GUI solo si su binario ya existe (ISO/dev build).
    local bin desktop pending=""
    while IFS='|' read -r bin desktop; do
        if apps_gui_bin "$bin"; then
            install -m644 "$REPO_ROOT/$desktop" "$APPS_DESKTOP_DIR/$(basename "$desktop")" \
                || { echo "ERROR: no se pudo instalar $desktop" >&2; return 1; }
        else
            pending="$pending $bin"
        fi
    done < <(apps_gui_map)
    if [ -n "$pending" ]; then
        nimbus_info "  [PENDIENTE] binarios GUI sin compilar:$pending"
        nimbus_info "    compílalos con iso/build-iso.sh o scripts/dev-remote (F12-T03)"
    fi
    command -v kbuildsycoca6 >/dev/null 2>&1 && kbuildsycoca6 >/dev/null 2>&1 || true
}

apps_check() {
    echo "-- apps:"
    local missing=0 app
    for app in nimbus-about nimbus-apps nimbus-bug-report nimbus-clock \
               nimbus-help nimbus-hw nimbus-migrate nimbus-missioncontrol \
               nimbus-spotlight nimbus-wallpaper nimbus-welcome backup; do
        if [ -d "$REPO_ROOT/apps/$app" ]; then nimbus_ok "apps/$app presente en el repo";
        else nimbus_fail "apps/$app ausente en el repo (repo incompleto)"; missing=1; fi
    done

    local rel src dst name
    while IFS= read -r rel; do
        src="$REPO_ROOT/$rel"
        name="$(basename "$rel")"
        if ! dst="$(apps_script_installed "$name")"; then
            nimbus_fail "falta $name en $APPS_BIN_DIR ni /usr/local/bin (paso de apps)"; missing=1
        elif ! cmp -s "$src" "$dst"; then
            nimbus_fail "$dst difiere del repo"; missing=1
        fi
    done < <(apps_shell_scripts)
    if [ "$missing" = "0" ]; then nimbus_ok "scripts de apps 1:1 en usuario o sistema"; fi

    local tools_missing=0
    while IFS= read -r rel; do
        src="$REPO_ROOT/$rel"
        name="$(basename "$rel")"
        if ! dst="$(apps_script_installed "$name")"; then
            nimbus_fail "falta $name en $APPS_BIN_DIR ni /usr/local/bin (herramientas)"; tools_missing=1
        elif ! cmp -s "$src" "$dst"; then
            nimbus_fail "$dst difiere del repo (herramientas)"; tools_missing=1
        fi
    done < <(apps_user_tools)
    if [ "$tools_missing" = "0" ]; then nimbus_ok "herramientas de usuario 1:1"; fi

    local res="${XDG_DATA_HOME:-$HOME/.local/share}/nimbus"
    if [ -d "$res/bar/presets" ] && [ -f "$res/bar/pins.txt" ] && \
       [ -f "$res/dock/kremarc-nimbus" ]; then
        nimbus_ok "recursos de barra/dock en $res"
    else
        nimbus_fail "faltan recursos de barra/dock en $res (paso de apps)"
    fi

    if dst="$(apps_desktop_installed org.nimbus.bugreport.desktop)"; then
        nimbus_ok "org.nimbus.bugreport.desktop ($dst)"
    else
        nimbus_fail "falta org.nimbus.bugreport.desktop en $APPS_DESKTOP_DIR ni /usr/share/applications"
    fi

    local bin desktop pend=""
    while IFS='|' read -r bin desktop; do
        if apps_gui_bin "$bin"; then nimbus_ok "binario $bin";
        else pend="$pend $bin"; fi
    done < <(apps_gui_map)
    if [ -n "$pend" ]; then
        nimbus_info "  [PENDIENTE] binarios GUI (los compila la ISO/dev):$pend"
    fi
}
