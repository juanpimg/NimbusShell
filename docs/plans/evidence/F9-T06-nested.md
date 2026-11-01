# Evidencia F9-T06 — export HTML/PDF de la chuleta + layout reversible

- `scripts/nimbus-i18n --export html` genera `docs/user-guide/shortcuts.html`
  autocontenido (CSS print-friendly, 33 atajos macOS→Plasma, cromo es/en);
  `--export pdf` usa weasyprint o pandoc+motor y sin ellos avisa (cómo
  instalar) con exit 0 documentado para no romper CI.
- Wizard verificado en F9-T03 (tarjetas Mac/Windows/Nimbus, `layout` por
  defecto mac): re-verificado reversible hoy con HOME temporal —
  `nimbus-layout mac --apply` → `ButtonsOnLeft=XIA`, `windows` →
  `ButtonsOnRight=IAX`, `--revert` restaura el backup (rc=0 en los tres).
