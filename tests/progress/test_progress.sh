#!/usr/bin/env bash
# Tests del ledger de progreso (F1-T06). Fixture temporal con 2 fases 50/50.
set -u
PROG="scripts/nimbus-progress"
fails=0

mkfixture() {
  # $1 = estados "x"/" " para T01 T02 T03 T04
  local f
  f="$(mktemp)"
  cat > "$f" <<'EOF'
## Fase 0 — Base (2 tareas, 50%, 1 semana)

- [ST0] **F0-T01 — Alfa.**
- [ST1] **F0-T02 — Beta.**

## Fase 1 — Resto (2 tareas, 50%, 1 semana)

- [ST2] **F1-T01 — Gamma.**
- [ST3] **F1-T02 — Delta.**
EOF
  sed -i "s/ST0/$1/;s/ST1/$2/;s/ST2/$3/;s/ST3/$4/" "$f"
  printf '%s' "$f"
}

check_total() {
  # $1 fixture, $2 esperado "Total: X/4 (Y%)"
  local out
  out="$("$PROG" --plan "$1")"
  if grep -qF "$2" <<<"$out"; then
    echo "ok: $2"
  else
    echo "FALLO: esperaba '$2', salida:"; echo "$out"; fails=$((fails+1))
  fi
}

f0="$(mkfixture ' ' ' ' ' ' ' ')"; check_total "$f0" "Total: 0/4 (0.0%)"
f1="$(mkfixture 'x' ' ' ' ' ' ')"; check_total "$f1" "Total: 1/4 (25.0%)"
f2="$(mkfixture 'x' ' ' 'x' ' ')"; check_total "$f2" "Total: 2/4 (50.0%)"
f4="$(mkfixture 'x' 'x' 'x' 'x')"; check_total "$f4" "Total: 4/4 (100.0%)"
rm -f "$f0" "$f1" "$f2" "$f4"

# --json parseable con python3
fj="$(mkfixture 'x' ' ' ' ' ' ')"
if python3 -c "import json,subprocess,sys; d=json.loads(subprocess.run(['$PROG','--plan','$fj','--json'],capture_output=True,text=True).stdout); sys.exit(0 if abs(d['percent']-25.0)<0.01 and d['done']==1 and d['total']==4 else 1)"; then
  echo "ok: --json parseable (25.0%, 1/4)"
else
  echo "FALLO: --json"; fails=$((fails+1))
fi
rm -f "$fj"

# --phase filtra
fj="$(mkfixture 'x' 'x' ' ' ' ')"
if "$PROG" --plan "$fj" --phase F0 | grep -q "F0" && ! "$PROG" --plan "$fj" --phase F0 | grep -q "^F1 "; then
  echo "ok: --phase F0 filtra"
else
  echo "FALLO: --phase"; fails=$((fails+1))
fi
rm -f "$fj"

# plan inexistente -> exit 2
if "$PROG" --plan /no/existe.md >/dev/null 2>&1; then
  echo "FALLO: plan inexistente deberia dar exit 2"; fails=$((fails+1))
else
  [ $? -eq 2 ] && echo "ok: plan inexistente exit 2" || { echo "FALLO: exit distinto de 2"; fails=$((fails+1)); }
fi

if [ "$fails" -eq 0 ]; then echo "TODOS LOS TESTS PASAN"; else echo "$fails FALLOS"; fi
exit "$fails"
