#!/usr/bin/env python3
"""Test del índice local Nimbus (F6-T02): compila y ejecuta tst_index (QtTest).

Uso: python3 tests/spotlight/test_index.py [--build-dir DIR]
Por defecto configura en un dir temporal fresco (nunca `build/` del repo,
evita CMakeCache rancio). TST_BUILD_DIR lo fuerza (útil para depurar).
Verifica: fuzzy, calculadora (precedencia/errores), parser .desktop,
clipboard (fallback klipper + parser), settings/files/tabs en vivo,
10k sintéticos <50ms, searchLocal <50ms.
"""
import argparse
import os
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(REPO, "apps", "nimbus-spotlight")


def run(cmd, **kw):
    print("+", " ".join(cmd), flush=True)
    r = subprocess.run(cmd, capture_output=True, text=True, **kw)
    print(r.stdout[-3000:] if r.stdout else "")
    print(r.stderr[-3000:] if r.stderr else "", file=sys.stderr)
    return r


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--build-dir", default=os.environ.get("TST_BUILD_DIR", ""))
    args = ap.parse_args()
    build = args.build_dir or tempfile.mkdtemp(prefix="nimbus-tst-",
                                                dir="/tmp/opencode")
    os.makedirs(build, exist_ok=True)
    print(f"build-dir: {build}", flush=True)
    r = run(["cmake", "-S", SRC, "-B", build, "-DCMAKE_BUILD_TYPE=Release"])
    if r.returncode != 0:
        print("FALLO: cmake configure", file=sys.stderr)
        return 1
    r = run(["cmake", "--build", build, "--target", "tst_index", "-j4"])
    if r.returncode != 0:
        print("FALLO: build", file=sys.stderr)
        return 1
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen",
               XDG_STATE_HOME=os.environ.get("XDG_STATE_HOME", "/tmp/opencode/nimbus-tst-state"))
    r = run([os.path.join(build, "tst_index")], env=env)
    if r.returncode != 0:
        print("FALLO: tst_index", file=sys.stderr)
        return 1
    print("OK: tst_index pasa (fuzzy, calc, desktop, clipboard, runners, perf <50ms)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
