#!/usr/bin/env python3
# Teclea texto en el guest vía HMP sendkey con layout US.
# Uso: hmp-type.py <socket-hmp> <texto>      (los \n del texto se envían como ret)
#      hmp-type.py <socket-hmp> --key <nombre>  (p. ej. ctrl-u, ctrl-c, ret)
# Seguro: solo escribe al monitor HMP indicado; no toca procesos.
import socket
import sys
import time

# Nombres de sendkey de QEMU para layout US. El mapa de type2.py tenía mal
# '/' (slash) y otros símbolos; este es el verificado por el verifier.
MAP = {
    " ": "spc", "-": "minus", "/": "slash", ".": "dot", ",": "comma",
    ";": "semicolon", "'": "apostrophe", "\\": "backslash",
    "[": "bracket_left", "]": "bracket_right", "`": "grave",
    "\n": "ret", "\t": "tab", "=": "equal", "_": "shift-minus",
    ">": "shift-dot", "<": "shift-comma", ":": "shift-semicolon",
    "?": "shift-slash", "!": "shift-1", '"': "shift-apostrophe",
    "$": "shift-4", "%": "shift-5", "&": "shift-7", "(": "shift-9",
    ")": "shift-0", "*": "shift-8", "+": "shift-equal",
    "|": "shift-backslash", "@": "shift-2", "#": "shift-3",
    "^": "shift-6", "{": "shift-bracket_left", "}": "shift-bracket_right",
    "~": "shift-grave",
}


def send(sock_path, name):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(sock_path)
    s.settimeout(3)
    f = s.makefile("rwb", buffering=0)
    try:
        f.read(4096)
    except Exception:
        pass
    f.write(("sendkey " + name + "\n").encode())
    time.sleep(0.035)
    try:
        f.read(4096)
    except Exception:
        pass
    s.close()


def main():
    if len(sys.argv) < 3:
        print("uso: hmp-type.py <socket-hmp> <texto> | --key <nombre>", file=sys.stderr)
        return 2
    sock_path = sys.argv[1]
    if sys.argv[2] == "--key":
        if len(sys.argv) != 4:
            print("uso: hmp-type.py <socket-hmp> --key <nombre>", file=sys.stderr)
            return 2
        send(sock_path, sys.argv[3])
        return 0
    for ch in sys.argv[2]:
        if ch in MAP:
            key = MAP[ch]
        elif ch.isupper():
            key = "shift-" + ch.lower()
        else:
            key = ch
        send(sock_path, key)
        time.sleep(0.025)
    return 0


if __name__ == "__main__":
    sys.exit(main())
