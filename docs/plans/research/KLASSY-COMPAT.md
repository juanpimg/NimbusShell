# Klassy compat Plasma 6.8 (C02) — research 2026-10-31

## 1. Upstream: ¿compatible?
- Último release: **v6.7.3 (18-sep-2026), "for Plasma 6.6.1+"** — no declara 6.8.
  https://github.com/paulmcauley/klassy/releases (v6.7.3 `ab86a63`; v6.7.2 `c144ad4`; v6.7.1 `2b4b6fd`)
- README exige **Plasma ≥6.6** (`git checkout plasma6.6`): https://github.com/paulmcauley/klassy
- Plasma **6.8.0 salió 14-oct-2026**: https://kde.org/announcements/plasma/6/6.8.0/
- Ramas activas (2026-10-13/21): `plasma6.6`, `master`, `migration-pre-674`, `feature/title-bar-app-menu-bar` y **`6.8temp`** → hay trabajo 6.8 en curso pero **sin release**.
- Cambio 6.8 relevante: **shadow-only decorations opt-in** (kdecoration MR#93; kwin #9147/#9566; breeze #612).
  Decoración debe declarar `"org.kde.kdecoration3": {"styles": ["shadow","titled"]}` y reaccionar a
  `KDecoration3::Decoration::style()`. Sin opt-in, la regla nueva "Window manager draws titlebar, frame, and shadows"
  no funciona con esa decoración. Fuente: https://blog.vladzahorodnii.com/2026/07/16/server-side-drop-shadows/
  y changelog https://kde.org/announcements/changelogs/plasma/6/6.7.5-6.8.0/ (kdecoration: shadow-only + Qt 6.11 / KF6 6.30).
- Klassy v6.7.2 sí se portó a `KDecoration3::BorderOutline` (alineado con 6.7/6.8, "algunos fixes de 6.8" según notas v6.7),
  pero **no hay evidencia de que declare `styles: [shadow,titled]`**. Conclusión: titled probablemente carga en 6.8,
  shadow-only probablemente NO.
- Patrón de roturas previas: 6.3 rompió todo (KDecoration2→3, issues #163/#184/#194, fix en 6.3 release 07-may-2025);
  6.5 rompió esquinas inferiores (issue #245, fix vía klassy-git/invent.kde.org/paulm/klassy). No hay issue abierto
  específico "Plasma 6.8" encontrado a 2026-10-31 (45 issues abiertos sin título 6.8 indexado).

## 2. Empaquetado (qué instala cada uno)
- **AUR `klassy` 6.7.3-1** (upd. 2026-09-18, mant. rocka/lilac): tarball `klassy-6.7.3.tar.gz`,
  instala `org.kde.klassy.so` (kdecoration3) + `kcm_klassydecoration.so` + presets + kstyle + temas.
  https://aur.archlinux.org/packages/klassy
- **AUR `klassy-git`** (upd. 2026-09-11): sigue rama upstream (`plasma6.6`/master), `provides/conflicts: klassy`.
  Es la vía para probar `6.8temp`/master sin esperar release. https://aur.archlinux.org/packages/klassy-git
- **AUR `klassy-bin` 6.7.2-1** (syrupderg): binario precompilado, **desactualizado (6.7.2 < 6.7.3)** → no usar.
  Repology confirma 6.7.3 (AUR) vs 6.7.2 (bin/rawhide): https://repology.org/project/klassy/packages
- **OBS `home:paulmcauley/klassy`**: precompilados OpenSUSE/Debian/Ubuntu/Fedora/Arch (citado en notas v6.5.2).
  Útil como referencia de build, no para Arch VM.
- Comentarios AUR relevantes: paulmcauley 2026-09-13 quita deps Qt5 innecesarias; 2026-08-17 kirigami ya no requerido
  desde v6.7. Historial: quejas de build en transiciones 6.3 (falta `KDecoration3Config.cmake` si kdecoration viejo).

## 3. Opciones si 6.7.3 falla en 6.8.2
| Opción | Coste | Riesgo |
|---|---|---|
| A. `klassy-git` (master o `6.8temp`) | Bajo (compila en VM, ~5-10 min) | Medio: código no releaseado, puede cambiar config `klassyrc` |
| B. Pin Plasma 6.7.x en VM | Medio (downgrade parcial, snapshot) | Medio-alto: diverge de F2 (6.8.2 medido); solo como control A/B |
| C. Aurorae/WhiteSur (SVG, sin API C++) | Bajo | Bajo riesgo técnico, alto coste visual: no es Klassy, inmune a breaks KDecoration (Xaver 2024: Aurorae no afectado) |
| D. KDecoration custom mínimo (fork Breeze+shadow style) | Alto (nuevo código, mantener) | Alto: deuda permanente; solo si Klassy muere upstream |

## 4. Test matrix en VM (Arch + Plasma 6.8.2, Wayland y X11)
1. Base: `plasmashell --version; kwin_wayland --version; pacman -Q kdecoration breeze kwin` → anotar.
2. Instalar `klassy-6.7.3` (AUR): `kwin --replace &` o relogin; `ls /usr/lib/qt6/plugins/org.kde.kdecoration3/org.kde.klassy.so`.
3. Aplicar decoración Klassy (kcm `kcm_klassydecoration`), abrir Dolphin+Konsole+app GTK (Nautilus) → **captura titled**.
4. `qdbus6 org.kde.KWin /KWin supportInformation | grep -i -A3 -B3 "decoration\|klassy\|shadow"` → guardar salida.
5. Regla 6.8 "Window manager draws titlebar, frame, and shadows" sobre Steam/VSCode-Wayland → **captura shadow-only**;
   PASS = sombra+outline+esquinas sin titlebar; FAIL esperado si Klassy no declara `styles`.
6. Repetir 2-5 con `klassy-git` (rama `6.8temp` si compila) → comparar capturas.
7. Fallback: Aurorae WhiteSur → captura control.
8. Criterio: titled OK + `supportInformation` sin crash = "compatible parcial"; shadow-only OK = "compatible total".

## 5. Recomendación
- **Probar `klassy` 6.7.3 en 6.8.2 primero (titled probablemente OK), con fallback `klassy-git@6.8temp` si shadow-only falla;
  no pin, no custom.** Aurorae solo como control visual.
- **Ruling propuesta:** Klassy-6.7.3-soportado-parcial-en-Plasma-6.8 (titled sí, shadow-only pendiente de release con opt-in `styles`).
