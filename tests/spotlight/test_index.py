#!/usr/bin/env python3
"""Test del índice local Nimbus (F6-T02): compila y ejecuta tst_index (QtTest).

Uso: python3 tests/spotlight/test_index.py [--build-dir ...]
Verifica: fuzzy, calculadora (precedencia/errores), parser .desktop,
10k sintéticos <50ms, searchLocal("kate") <50ms.
"""
import os
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(REPO, "apps", "nimbus-spotlight")


def run(cmd, **kw):
    print("+", " ".join(cmd), flush=True)
    r = subprocess.run(cmd, capture_output=True, text=True, **kw)
    print(r.stdout[-3000:] if r.stdout else "")
    print(r.stderr[-3000:] if r.stderr else "", file=sys.stderr)
    return r


def main():
    build = os.environ.get("TST_BUILD_DIR", os.path.join(SRC, "build"))
    os.makedirs(build, exist_ok=True)
    r = run(["cmake", "-S", SRC, "-B", build, "-DCMAKE_BUILD_TYPE=Release"])
    if r.returncode != 0:
        print("FALLO: cmake configure", file=sys.stderr)
        return 1
    r = run(["cmake", "--build", build, "--target", "tst_index", "nimbus-spotlight", "-j4"])
    if r.returncode != 0:
        print("FALLO: build", file=sys.stderr)
        return 1
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen",
               XDG_STATE_HOME=os.environ.get("XDG_STATE_HOME", "/tmp/opencode/nimbus-tst-state"))
    r = run([os.path.join(build, "tst_index")], env=env)
    if r.returncode != 0:
        print("FALLO: tst_index", file=sys.stderr)
        return 1
    print("OK: tst_index pasa (fuzzy, calc, desktop, perf 10k <50ms)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
