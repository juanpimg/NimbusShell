# F2-ISO Integración — staging ISO y nimbus-installed-setup (autoría, VM pendiente)

## Problema
`iso/calamares/modules/shellprocess-nimbus.conf` invocaba
`/usr/local/bin/nimbus-installed-setup` (inexistente) y el perfil no
estagiaba dotfiles/paquetes/calamares en `airootfs`: una ISO instalaría
Plasma stock.

## Ficheros
- `iso/build-iso.sh` (nuevo): `set -u`, `--check`/`--stage-only`/`--out`/`--skip-apps`, idempotente.
- `iso/profile/airootfs/usr/local/bin/nimbus-installed-setup` (nuevo): chroot root, idempotente, log `/var/log/nimbus-installed-setup.log`.
- `iso/profile/packages.x86_64`: +`qt6-declarative`, +`kdecoration`; `krunner`/`layer-shell-qt` ya estaban; `qt6-tools` solo build, `klassy` AUR fuera (documentado).
- `iso/README.md`: orden `--check` → `--stage-only` → build VM → hash; rollback; parche klassy.

## Staging OK (host, sin root)
`./iso/build-iso.sh --stage-only --out /tmp/nimbus-stage` exit 0, re-ejecutable (idempotente).
Árbol: 79 ficheros — calamares 13 módulos, skel 18, `/usr/local/bin` 8 (4 scripts + setup + 3 binarios),
temas nimbus/sddm, KWin scripts ×3, preset + parche klassy.

## Apps construidas (cmake+ninja, DESTDIR a /usr/local)
`nimbus-bar`, `nimbus-apps`, `nimbus-spotlight` OK en el host (sin `--skip-apps`).

## Validación
`bash -n` OK ×2; `shellcheck -S warning` cero ×2; `--check` exit 0;
`find` sin activos Apple (solo menciones R-APPLE y fallback tipográfico, sin `.sfnt`/`.otf`).

## Commit
`feat(F2): staging ISO y nimbus-installed-setup` (esta rama, sin push).

## Riesgos para el build VM
1. `mkarchiso` + root solo en VM; snapshot `<SNAPSHOT>` sin congelar (F2-T01).
2. `klassy` AUR ausente en live → fallback Breeze hasta que el instalado aplique preset + parche.
3. `nimbus-installed-setup` sin probar en chroot real (pasos klassy/kpackagetool degradan a AVISO).
4. Primer boot Plasma / Calamares E2E pendientes (F2-T06/T07/T08).
