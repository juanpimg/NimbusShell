# F7-T05 nested — Drag a otro Space con setDesktop real

Fecha: 2026-10-31. Rama `plasma/f7-mc`. Mismo harness (10 ventanas,
4 Spaces). Vía `/MC moveFirstTo` (misma ruta que el DropArea del tile:
`moveWindowToDesktop` → one-shot `wins[j].desktops = [dd]` + `refresh`
con re-push para verificar).

## 5 casos

1. Mover a Space 4: `drag1=KCalc -> Escritorio 4` ✓ (recuento posterior
   coherente).
2. Volver a Space 1: `drag2=KCalc -> Escritorio 1` ✓.
3. Mismo Space: `drag_same=KCalc -> Escritorio 1` (no-op válido) ✓.
4. Índice inválido: `drag_invalid=` vacío + rc=0 (sin crash, sin mover) ✓.
5. UI DropArea sobre tile de Space → `moveWindowToDesktop` (código +
   qmllint; click posicional E2E pendiente de pointer lab) — documentado.

## Sin pérdidas

`total_antes=10`, `total_tras1=10`, `total_tras2=10` (10 ventanas reales,
recuento vía re-push scripting tras cada mover) ✓.
