# Atribución y Licencias de Temas y Activos Visuales (F2-T04 / R-APPLE)

Este documento certifica el origen y licenciamiento de todos los componentes de la fundación visual de NimbusShell (`packages/themes/` y `assets/`), garantizando el cumplimiento estricto de la regla **R-APPLE: Cero activos propietarios de Apple**.

## 1. Regla de Cumplimiento R-APPLE
- **Queda estrictamente prohibida la inclusión o redistribución de marcas, logotipos, tipografías propietarias (San Francisco / SF Pro), fondos de pantalla propietarios o efectos de sonido de Apple Inc.**
- Toda la experiencia visual se construye mediante arte original libre, tipografías abiertas y temas de código abierto con licencia compatible (GPL / Apache / OFL / CC0).

---

## 2. Inventario de Componentes y Atribución

### 2.1 Temas de Decoración y Widgets
- **Klassy (KDecoration3 / KWin):**
  - **Autor:** Paul McAuley (`paulmcauley`)
  - **Licencia:** GNU General Public License v2.0 or later (GPL-2.0-or-later)
  - **Repositorio:** https://github.com/paulmcauley/klassy
  - **Uso en Nimbus:** Preset Tahoe (`nimbus-tahoe.klpw`) y parches para botones de ventana y espaciado nativo.

- **Kvantum (Tema Qt / SVG):**
  - **Autor:** Tsu Jan (`tsujan`)
  - **Licencia:** GNU General Public License v3.0 (GPL-3.0)
  - **Repositorio:** https://github.com/tsujan/Kvantum
  - **Uso en Nimbus:** Motor de renderizado de controles translúcidos (`nimbus.kvconfig`).

- **Aurorae MacTahoe (KDecoration3 / Aurorae):**
  - **Autor:** Lester Cordero Murillo (`lestercorderomurillo/macos-tahoe-liquid-kde`) / Vince Liuice
  - **Licencia:** GNU General Public License v3.0 (GPL-3.0)
  - **Uso en Nimbus:** Decoración de ventanas Tahoe (`MacTahoeLiquidKde-Dark` y `Light`) con semáforos vectoriales y radios de 16px.

- **Acrylic Glass / Liquid Glass (KWin Effect):**
  - **Autor:** 4v3ngR (`kwin-effects-glass`), taj-ny (`kwin-effects-forceblur`), Lester Cordero Murillo
  - **Licencia:** GNU General Public License v3.0 or later (GPL-3.0-or-later)
  - **Uso en Nimbus:** Shaders de refracción Snell, dispersión cromática, iluminación specular y desenfoque frosted para KWin 6.8+.

- **WhiteSur-kde:**
  - **Autor:** Vince Liuice (`vinceliuice`)
  - **Licencia:** GNU General Public License v3.0 (GPL-3.0)
  - **Repositorio:** https://github.com/vinceliuice/WhiteSur-kde
  - **Uso en Nimbus:** Estilo de iconos y cursores con opción `-p` (neutralizada sin marcas registradas ni logotipos de terceros).

### 2.2 Tipografía
- **Inter:**
  - **Diseñador:** Rasmus Andersson
  - **Licencia:** SIL Open Font License 1.1 (OFL-1.1)
  - **Uso en Nimbus:** Fuente de interfaz del sistema (UI). No se redistribuyen binarios en el repositorio; se declara como dependencia de sistema.

- **JetBrains Mono:**
  - **Diseñador:** Philipp Nurullin, Konstantin Bulenkov (JetBrains)
  - **Licencia:** Apache License 2.0
  - **Uso en Nimbus:** Tipografía monoespaciada fija para terminal y código.

### 2.3 Fondos de Pantalla y Arte Gráfico
- **Sequoia NPS (`assets/sequoia-light.jpg` y `assets/sequoia-dark.jpg`):**
  - **Origen:** Fotografía del Parque Nacional Sequoia (U.S. National Park Service / dominio público / CC0).
  - **Edición y gradación:** Proyecto NimbusShell (CC0 / Dominio Público).
  - **Garantía:** No contiene fondos de pantalla propietarios de macOS.

- **Logotipo N e Iconografía de Sistema:**
  - **Autor:** Proyecto NimbusShell
  - **Licencia:** CC0 1.0 Universal / GPL-3.0-or-later.
  - **Garantía:** Arte vectorial SVG 100% original.

### 2.4 Sonidos de Sistema
- **Nimbus Sound Theme (`packages/themes/sounds-nimbus/`):**
  - **Generación:** Síntesis sonora algorítmica procedimental (`generate_sounds.py` con math/wave/numpy).
  - **Licencia:** CC0 1.0 Universal / GPL-3.0-or-later.
  - **Garantía:** Cero grabaciones o muestras de audio extraídas de macOS u otros sistemas operativos propietarios.
