# apps/nimbus-hw (`org.nimbus.hw`)

Detección de hardware estilo chwd: GPU (incl. perfil NVIDIA Wayland,
`modeset=1`), Wi-Fi, impresora, energía (`power-profiles-daemon`).

- **Qué va:** detección, presets por hardware, tests en VM + hardware.
- **Qué no:** el perfil ISO en sí (vive en `iso/profile/`); aquí solo la
  herramienta de detección y presets.
