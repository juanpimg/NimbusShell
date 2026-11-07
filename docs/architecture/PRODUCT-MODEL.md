# Modelo de producto — NimbusOS y NimbusShell

> Documento canónico de fronteras. Si una decisión no encaja aquí, se discute
> antes de implementarla.

## Dos productos, una dirección

```
CachyOS (base)
  └── NimbusOS (ISO instalable + sistema)
        └── NimbusShell (escritorio Plasma + apps + tema + ajustes)
```

- **NimbusOS** es el **sistema instalable**: ISO, Calamares, arranque, paquetes
  del sistema, usuarios, servicios, drivers, actualizaciones y ajustes de
  sistema. Su unidad de entrega es una **ISO**.
- **NimbusShell** es la **capa de escritorio**: Plasma 6.8, tema Tahoe, barra,
  Dock, Spotlight, Mission Control, KCM de ajustes, apps propias, scripts,
  dotfiles canónicos y pruebas. Su unidad de entrega es un **commit/tag** y,
  opcionalmente, un `install.sh` para cualquier Arch ya instalado.
- **Dirección única:** NimbusShell → NimbusOS. NimbusOS consume NimbusShell;
  nunca al revés a mano.

## Fuente de verdad

| Área | Vive en | Consumidor |
|---|---|---|
| Dotfiles del escritorio | `NimbusShell/dotfiles/` | NimbusOS (skel) |
| Paquetes del escritorio | `NimbusShell/packages/plasma.list` | NimbusOS (append) |
| Tema Tahoe (color, Kvantum, Aurorae, fondos) | `NimbusShell/packages/themes/` | NimbusOS + `install.sh` |
| Barra, apps y KCM | `NimbusShell/packages/shell/`, `apps/`, `packages/kcm/` | NimbusOS (build) |
| Sistema, ISO, Calamares, arranque, drivers | `NimbusOS/` | Solo NimbusOS |
| Skel del usuario | Generado desde `NimbusShell/dotfiles/` | NimbusOS build |

## Lo que NO es cada producto

- NimbusShell **no** particiona, no instala el sistema, no gestiona GRUB ni
  drivers. Puede instalar el escritorio en un Arch existente, pero no es una ISO.
- NimbusOS **no** define el tema ni los dotfiles a mano. Los importa de
  NimbusShell en el build y registra el commit usado.

## Flujo de release

1. NimbusShell se valida con `./scripts/ci.sh` y se etiqueta `vX.Y.Z`.
2. NimbusOS fija ese commit/tag en su manifiesto (`NIMBUS_SHELL_COMMIT`).
3. El build de NimbusOS sincroniza skel, paquetes del escritorio, tema y
   binarios GUI desde NimbusShell.
4. Se construye y valida la ISO en VM/hardware (F12).
5. Se etiqueta NimbusOS `vX.Y.Z` solo si la ISO pasa la matriz de aceptación.

## Estado actual (2026-11-07)

- **NimbusShell:** Plasma es la línea activa; Hyprland queda congelado en
  `legacy/hyprland/`. 103/112 tareas (93.0%), CI verde, binarios GUI + KCM
  compilables con `scripts/build-components`.
- **NimbusOS:** `main` sigue siendo la ISO Hyprland estable. La línea nueva es
  la rama **`plasma-migration`**, que consume NimbusShell y sustituye
  Hyprland/MacShell por Plasma/SDDM/NimbusShell. No se mergea hasta validar la
  ISO Plasma en VM (F12).
- **Skel:** portado de forma aditiva en `plasma-skel-sync`; el perfil Plasma
  usará el skel generado desde NimbusShell y eliminará el legado en el build.

## Regla de oro

Si algo afecta a cómo se ve o se comporta el escritorio, se implementa en
NimbusShell y se importa. Si algo afecta a cómo se instala o arranca el sistema,
se implementa en NimbusOS. No se duplica a mano.
