# Sesión 2026-11-07 — reparación de coherencia, CI y despliegue

> Handoff de la sesión de reparación. Objetivo: dejar el repo sin trabajo
> huérfano, con documentación coherente y con el instalador desplegando lo que
> promete. Sin root, sin red y sin tocar el HOME real.

## Qué estaba roto

1. **134 entradas sin commitear** (73 archivos modificados + 61 sin trackear),
   incluidas apps completas, tests que `scripts/ci.sh` ya invocaba, temas y el
   handoff maestro. Un `checkout` habría perdido el trabajo del 4-nov.
2. **Documentación cruzada:** `docs/INDEX.md` apuntaba al handoff del 2-nov y
   publicaba 60/112; el README describía Hyprland como perfil activo.
3. **Tema incoherente:** `scripts/apply-theme` aplicaba Klassy mientras el
   `kwinrc` canónico usa Aurorae `MacTahoeLiquidKde-*`; `install.sh` nunca
   llamaba a `apply-theme`.
4. **Apps no desplegadas:** `lib/apps.sh` decía "sin componentes desplegables"
   y no instalaba ni siquiera las apps de script (`nimbus-hw`, migradores,
   backup, bug-report).
5. **CI ensuciaba el repo:** `tests/vm/nimbus-hw-check.sh` escribía por defecto
   en `spikes/nested/nimbus-hw-check.log` (trackeado).

## Qué se hizo

- **4 commits de consolidación** del trabajo del 4-nov (UI/temas/apps,
  tests/CI/evidencia, fixes de scripts y docs/handoff/ledger) y **varios
  commits de reparación** (tema/apps/CI, docs, apps de la ISO en
  `/usr/local/bin` y test de `themes_deploy`). Ver `git log --oneline`.
- `scripts/apply-theme` ahora copia y aplica la decoración Aurorae de la
  variante (`Dark`/`Light`), valida `library`/`theme` en `kwinrc` y revierte
  también el tema copiado. `NIMBUS_NO_LIVE=1` evita tocar el fondo de la
  sesión real durante los tests.
- `lib/themes.sh` instala los recursos del tema con
  `apply-theme --resources-only` y respeta la variante si ya existe
  `~/.config/nimbus-theme-applied`; no reescribe `kdeglobals`/`kwinrc` para no
  provocar drift en el `--check` 1:1 (los dotfiles ya activan el tema).
- `scripts/nimbus-theme` también cambia la decoración Aurorae al alternar
  claro/oscuro (antes solo cambiaba color scheme y fondo).
- El instalador despliega las herramientas de usuario y sus recursos en
  `~/.local/share/nimbus/`; `nimbus-theme` ya encuentra el tema, y el autostart
  `nimbus-theme-init.desktop` aplica la variante al entrar.
- Nuevo `scripts/build-components`: compila e instala los 9 binarios GUI
  (`nimbus-bar`, apps y `nimbus-wallpaper`) **y el KCM** en un prefijo de
  usuario, con `--check`, `--filter` y logs por componente. La ISO también
  compila `nimbus-wallpaper` desde ahora.
- Nuevo `scripts/nimbus-skel-sync`: port **aditivo** de `dotfiles/` al skel de
  NimbusOS con allowlist para Hyprland/MacShell/ISO; `--check` detecta
  faltantes/diferencias/extras no permitidos y `--apply` copia sin borrar.
- `lib/apps.sh` despliega las 7 apps de script y 12 herramientas de usuario
  (`nimbus-theme`, `nimbus-dock`, `nimbus-updates`, `nimbus-layout`…) en
  `~/.local/bin` (1:1, con `cmp`), instala sus recursos de barra/dock y el
  desktop de bug-report, y marca los binarios GUI como `[PENDIENTE]` con la
  orden de compilación.
- `tests/vm/nimbus-hw-check.sh` usa `/tmp/opencode` por defecto; solo escribe
  en `spikes/` con `--out` explícito.
- Nuevos gates: `tests/apps/test_apps_deploy.sh`,
  `tests/install/test_deploy_home.sh` y
  `tests/docs/test_docs_consistency.sh`.
- Docs corregidos: README Plasma, `docs/INDEX.md`, `ESTADO.md`, handoff,
  `docs/SKEL-SYNC.md` y Rulings Hyprland movidas a `legacy/hyprland/README.md`.

## Evidencia ejecutada

```
$ scripts/nimbus-progress
Total: 103/112 (93.0%)

$ ./scripts/ci.sh
CI VERDE.   # 44 grupos; incluye tema, apps, docs, deploy, build y skel sync

$ bash tests/theme/test_apply_theme.sh
PASS: test_apply_theme.sh completado con éxito.

$ bash tests/theme/test_themes_deploy.sh
Resultado: 15 ok, 0 fallos

$ bash tests/theme/test_nimbus_theme.sh
Resultado: 14 ok, 0 fallos

$ bash tests/apps/test_apps_deploy.sh
Resultado: 28 ok, 0 fallos

$ bash tests/install/test_deploy_home.sh
Resultado: 10 ok, 0 fallos   # dotfiles+tema+KWin+dock+apps 1:1 en HOME temporal

$ scripts/build-components --prefix /tmp/opencode/nimbus-prefix-all
BUILD_OK components=10 prefix=/tmp/opencode/nimbus-prefix-all

$ scripts/build-components --check --prefix /tmp/opencode/nimbus-prefix-all
BUILD_COMPONENTS_CHECK_OK

$ bash tests/install/test_build_components.sh
Resultado: 13 ok, 0 fallos   # nimbus-about + KCM en prefijo aislado

$ bash tests/install/test_skel_sync.sh
Resultado: 13 ok, 0 fallos   # port aditivo, legacy/ISO intactos

$ scripts/nimbus-skel-sync --apply
SKEL_SYNC_APPLIED actualizados=59
$ scripts/nimbus-skel-sync --check
SKEL_SYNC_OK   # 62 ficheros 1:1; 9 extras legacy/ISO permitidos
$ diff -rq dotfiles/ ../NimbusOS/nimbus-overlay/etc/skel/ | wc -l
9
$ (cd ../NimbusOS && ./build_iso.sh --check-only)
CHECK-ONLY PASS

$ bash tests/docs/test_docs_consistency.sh
Resultado: 14 ok, 0 fallos

$ HOME=$(mktemp -d) ./install.sh --check
CHECK ROJO: hay drift (ver [FALTA] arriba).   # exit 1 esperado en host no convergido
# sin "unbound variable", "command not found" ni errores de sintaxis
```

## Reestructuración 2026-11-07 (NimbusOS Plasma)

- Nuevo modelo de producto en `docs/architecture/` (NimbusOS = sistema;
  NimbusShell = escritorio; dirección NimbusShell → NimbusOS).
- NimbusOS `plasma-migration`: perfil Plasma real con
  `packages.nimbus-plasma.append` (127 paquetes), overlay SDDM/Calamares/barra,
  skel generado desde NimbusShell y `build-components` para GUI + KCM.
- `./build_iso.sh --check-only --profile plasma` → `CHECK-ONLY PASS`.
- `./scripts/verify-plasma.sh` → `VERIFY-PLASMA PASS` (check-only + skel + CI).
- El perfil `legacy-hypr` sigue pasando `--check-only` para rollback; `main`
  de NimbusOS no se toca hasta validar la ISO Plasma en VM.

## Deuda que sigue abierta (no se finge resuelta)

- **F12-T01…T06:** hardening, multimonitor/HiDPI, rendimiento/batería, ISO
  final, Secure Boot/licencias y soak de 8 h. Requieren VM/hardware real.
- **Binarios GUI + KCM:** ya se compilan/instalan en `~/.local` con
  `scripts/build-components` (9 GUI + KCM verificado); la ISO final sigue
  siendo F12-T03.
- **Skel de NimbusOS:** port aplicado y rama publicada en
  `origin/plasma-skel-sync` (commit `917cc0f`, 59 ficheros,
  `CHECK-ONLY PASS`); pendiente de revisión/merge en NimbusOS. `main` de
  NimbusOS intacto. Ver `docs/SKEL-SYNC.md`.
- **F13-T01:** contribuciones upstream.
- **F0-T03/T04:** spikes históricos; sus resultados viven en F5/F7 y no se
  marcan para no inflar el ledger.

## Reglas respetadas

- Sin root y sin tocar paquetes del host.
- Sin activos de Apple.
- Backups intactos (`~/.config/nimbusshell-backup-*`).
- Evidencia real de cada cambio (CI y tests arriba).
