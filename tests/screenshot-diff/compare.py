#!/usr/bin/env python3
"""Compara dos capturas PNG y devuelve el porcentaje de pixeles distintos.

Uso: compare.py <golden.png> <captura.png> [--threshold N] [--crop x,y,w,h] [--out diff.png]
Dependencias: solo Pillow (PIL). Sin numpy ni OpenCV.
"""
import argparse
import sys

try:
    from PIL import Image, ImageChops
except ImportError:
    print("error: falta Pillow (python3 -m pip install pillow)", file=sys.stderr)
    sys.exit(2)


def parse_crop(s):
    try:
        x, y, w, h = (int(v) for v in s.split(","))
    except ValueError:
        raise argparse.ArgumentTypeError("crop debe ser x,y,w,h con enteros")
    if w <= 0 or h <= 0:
        raise argparse.ArgumentTypeError("crop con w,h <= 0")
    return (x, y, w, h)


def main():
    ap = argparse.ArgumentParser(
        description="Diff de capturas: %% de pixeles distintos (R-APPLE: goldens propios).")
    ap.add_argument("golden", help="PNG de referencia (tests/golden/local/)")
    ap.add_argument("captura", help="PNG a comparar")
    ap.add_argument("--threshold", type=float, default=0.0,
                    help="umbral %% admitido (default 0). Exit 0 si diff <= umbral.")
    ap.add_argument("--crop", type=parse_crop, default=None,
                    metavar="x,y,w,h", help="recorte comun a ambas imagenes")
    ap.add_argument("--out", default=None, metavar="diff.png",
                    help="guarda mapa de diferencias en este PNG")
    args = ap.parse_args()

    try:
        a = Image.open(args.golden).convert("RGB")
        b = Image.open(args.captura).convert("RGB")
    except FileNotFoundError as e:
        print(f"error: fichero no encontrado: {e.filename}", file=sys.stderr)
        return 2
    except Exception as e:
        print(f"error: no se pudo abrir imagen: {e}", file=sys.stderr)
        return 2

    if args.crop:
        x, y, w, h = args.crop
        for name, im in (("golden", a), ("captura", b)):
            if x < 0 or y < 0 or x + w > im.width or y + h > im.height:
                print(f"error: crop x,y,w,h={x},{y},{w},{h} fuera de "
                      f"{name} ({im.width}x{im.height})", file=sys.stderr)
                return 2
        a = a.crop((x, y, x + w, y + h))
        b = b.crop((x, y, x + w, y + h))

    if a.size != b.size:
        print(f"error: tamanos distintos: golden {a.size[0]}x{a.size[1]} "
              f"vs captura {b.size[0]}x{b.size[1]}", file=sys.stderr)
        return 2

    diff = ImageChops.difference(a, b)
    bbox = diff.getbbox()
    if bbox is None:
        pct = 0.0
    else:
        hist = diff.convert("L").histogram()
        same = hist[0]
        total = a.width * a.height
        pct = (total - same) * 100.0 / total

    print(f"diff: {pct:.2f}% ({a.width}x{a.height})")
    if args.out:
        # Mapa amplificado: diferencias en rojo sobre fondo negro.
        mask = diff.convert("L").point(lambda v: 255 if v else 0)
        red = Image.new("RGB", a.size, (255, 0, 0))
        black = Image.new("RGB", a.size, (0, 0, 0))
        Image.composite(red, black, mask).save(args.out)
        print(f"mapa: {args.out}")
    return 0 if pct <= args.threshold else 1


if __name__ == "__main__":
    sys.exit(main())
