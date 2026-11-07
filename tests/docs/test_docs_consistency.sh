#!/usr/bin/env bash
# tests/docs/test_docs_consistency.sh — evita handoffs y ledger obsoletos.
# Solo lectura: comprueba que README/ESTADO/AGENTS/INDEX apuntan al último
# handoff y que las cifras publicadas coinciden con scripts/nimbus-progress.
set -u

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "  [OK] $*"; }
bad() { FAIL=$((FAIL + 1)); echo "  [FALLO] $*"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT" || exit 2

latest="$(ls docs/SESSION-*-HANDOFF.md 2>/dev/null | sort | tail -n 1)"
[ -n "$latest" ] || { echo "FALLO: no hay docs/SESSION-*-HANDOFF.md"; exit 1; }
ok "handoff más reciente: $latest"

for f in README.md ESTADO.md AGENTS.md docs/INDEX.md; do
    if grep -Fq "$latest" "$f"; then ok "$f apunta a $latest"; else bad "$f no referencia $latest"; fi
done

ledger="$(scripts/nimbus-progress 2>/dev/null | sed -n 's/^Total: \([0-9]*\)\/\([0-9]*\) (\([0-9.]*\)%).*/\1\/\2|\3/p' | head -n 1)"
if [ -n "$ledger" ]; then
    ratio="${ledger%%|*}"; pct="${ledger##*|}"
    ok "ledger: $ratio ($pct%)"
    for f in README.md ESTADO.md; do
        grep -Fq "$ratio" "$f" && ok "$f publica $ratio" || bad "$f no publica $ratio"
        grep -Fq "$pct%" "$f" && ok "$f publica $pct%" || bad "$f no publica $pct%"
    done
    grep -Fq "$ratio" "$latest" && ok "$latest publica $ratio" || bad "$latest no publica $ratio"
else
    bad "no se pudo leer el ledger con scripts/nimbus-progress"
fi

if grep -q '60/112' docs/INDEX.md; then bad "docs/INDEX.md conserva el ledger viejo 60/112"; else ok "docs/INDEX.md sin ledger viejo"; fi
if grep -q 'Entras a Hyprland' README.md; then bad "README.md sigue describiendo Hyprland como perfil activo"; else ok "README.md sin instrucciones Hyprland activas"; fi
if [ -f docs/SKEL-SYNC.md ]; then ok "docs/SKEL-SYNC.md presente"; else bad "falta docs/SKEL-SYNC.md"; fi

echo "Resultado: $PASS ok, $FAIL fallos"
[ "$FAIL" -eq 0 ]
