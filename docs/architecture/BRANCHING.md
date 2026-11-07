# Ramas, versiones y pines

## NimbusShell

- `main`: **Plasma activo**. Todo cambio de escritorio entra aquí.
- `legacy/hyprland`: perfil antiguo congelado (solo lectura/referencia).
- `feat/*`, `fix/*`: ramas cortas; se mergean a `main` con CI verde.
- Tags: `vX.Y.Z` cuando el escritorio pasa la matriz de aceptación.

## NimbusOS

- `main`: ISO **estable** (hoy Hyprland) hasta que la ISO Plasma pase la
  validación real en VM/hardware.
- `plasma-migration`: línea nueva Plasma + NimbusShell. No se mergea a `main`
  hasta F12 (VM/ISO real, rendimiento, instalación, soak).
- `plasma-skel-sync`: port aditivo del skel; base de `plasma-migration`.
- Tags de ISO: solo con build verificado y `iso.manifest` actualizado.

## Pin entre repos

`NimbusOS` registra en `iso.manifest`:

```
NIMBUS_SHELL_COMMIT=<sha de NimbusShell>
NIMBUS_SHELL_TAG=<tag opcional>
```

El build de Plasma sincroniza skel y paquetes desde ese commit, no desde el
`HEAD` móvil. Subir el pin exige revalidar la ISO.

## Regla de merge

1. NimbusShell: CI verde + evidencia.
2. NimbusOS Plasma: `build_iso.sh --check-only --profile plasma` verde.
3. ISO real en VM: instalación + primer arranque + matriz F12.
4. Solo entonces `plasma-migration → main` y tag de NimbusOS.
