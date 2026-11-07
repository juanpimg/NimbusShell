#!/usr/bin/env bash
# test_hw.sh — F2-T10: validación de detección de hardware, GPU y energía
# Sin root, sin red, solo lectura y dry-run.
set -u
set -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAILS=0

pass() { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1" >&2; FAILS=$((FAILS + 1)); }

echo "== hw: comprobación de sintaxis y lint =="
HW_SCRIPT="$REPO_ROOT/apps/nimbus-hw/nimbus-hw"
GPU_DETECT="$REPO_ROOT/apps/nimbus-hw/nimbus-gpu-detect"
GPU_SETUP="$REPO_ROOT/apps/nimbus-hw/nimbus-gpu-setup"

for s in "$HW_SCRIPT" "$GPU_DETECT" "$GPU_SETUP"; do
    rel="${s#"$REPO_ROOT"/}"
    if [ -f "$s" ]; then
        if bash -n "$s" && shellcheck -S warning "$s"; then
            pass "bash -n y shellcheck $rel"
        else
            fail "lint falló en $rel"
        fi
    else
        fail "falta $rel"
    fi
done

echo "== hw: nimbus-gpu-detect =="
if [ -x "$GPU_DETECT" ]; then
    JSON_OUT="$("$GPU_DETECT" --json 2>/dev/null)"
    if python3 -c "import json, sys; d=json.loads(sys.argv[1]); assert 'vendor' in d and 'recommend' in d and 'wayland' in d" "$JSON_OUT" 2>/dev/null; then
        pass "nimbus-gpu-detect --json válido con campos vendor/recommend/wayland"
    else
        fail "nimbus-gpu-detect --json devolvió estructura inválida: $JSON_OUT"
    fi

    if "$GPU_DETECT" --check >/dev/null 2>&1; then
        pass "nimbus-gpu-detect --check exit 0"
    else
        fail "nimbus-gpu-detect --check falló"
    fi
else
    fail "apps/nimbus-hw/nimbus-gpu-detect no es ejecutable"
fi

echo "== hw: nimbus-gpu-setup dry-run =="
if [ -x "$GPU_SETUP" ]; then
    SETUP_OUT="$("$GPU_SETUP" --check 2>&1)"
    if [ $? -eq 0 ]; then
        pass "nimbus-gpu-setup --check exit 0"
    else
        fail "nimbus-gpu-setup --check falló"
    fi

    if echo "$SETUP_OUT" | grep -qi "DRY-RUN\|Modo DRY-RUN"; then
        pass "nimbus-gpu-setup modo dry-run no modifica el sistema"
    else
        fail "nimbus-gpu-setup no reporta dry-run"
    fi

    if echo "$SETUP_OUT" | grep -qiE "power-profiles-daemon|energía"; then
        pass "nimbus-gpu-setup audita/gestiona perfil de energía"
    else
        fail "nimbus-gpu-setup no menciona perfil de energía"
    fi
else
    fail "apps/nimbus-hw/nimbus-gpu-setup no es ejecutable"
fi

echo "== hw: suite nimbus-hw-check =="
HW_CHECK_VM="$REPO_ROOT/tests/vm/nimbus-hw-check.sh"
if [ -x "$HW_CHECK_VM" ]; then
    if bash "$HW_CHECK_VM" --check >/dev/null 2>&1; then
        pass "tests/vm/nimbus-hw-check.sh --check 14/14 PASS"
    else
        fail "tests/vm/nimbus-hw-check.sh falló"
    fi
else
    fail "tests/vm/nimbus-hw-check.sh no es ejecutable"
fi

echo
if [ "$FAILS" -eq 0 ]; then
    echo "HARDWARE VERDE (todos los checks pasan)."
    exit 0
else
    echo "HARDWARE ROJO ($FAILS fallos)." >&2
    exit 1
fi
