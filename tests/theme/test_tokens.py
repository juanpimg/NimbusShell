#!/usr/bin/env python3
"""F3-T01: valida tokens.json contra contrato §2 + WCAG AA (A4).

label/bg exige 4.5:1; label2/accent (secundarios, base+alfa sobre bg)
exigen 3:1 (umbral large-text/UI, §2.5 a11y [HIG]).

Regla de uso (no verificable por este test, solo documentada):
label2/accent solo ≥15px/3:1; texto pequeño siempre label.
"""
import json
import sys
from pathlib import Path

TOKENS = Path(__file__).resolve().parent.parent.parent / "packages" / "themes" / "nimbus-tokens" / "tokens.json"


def lum(hex6):
    c = [int(hex6[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    f = lambda v: v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4  # noqa: E731
    c = [f(v) for v in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def contrast(a, b):
    hi, lo = max(lum(a), lum(b)), min(lum(a), lum(b))
    return (hi + 0.05) / (lo + 0.05)


def blend(fg, bg, alpha):
    f = [int(fg[i:i + 2], 16) for i in (1, 3, 5)]
    b = [int(bg[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join("%02X" % round(alpha * x + (1 - alpha) * y) for x, y in zip(f, b))


def check(cond, msg, fails):
    print(("PASS" if cond else "FAIL"), "-", msg)
    if not cond:
        fails.append(msg)


def main():
    fails = []
    t = json.loads(TOKENS.read_text())

    for mode in ("light", "dark"):
        c = t["colors"][mode]
        for k in ("label", "label2", "label3", "label4", "separator", "separatorAlpha",
                  "accent", "success", "destructive", "warning", "bg", "bgElevated", "bg2",
                  "trafficRed", "trafficYellow", "trafficGreen"):
            check(k in c, f"colors.{mode}.{k} existe", fails)
        check(isinstance(c["separatorAlpha"], (int, float)),
              f"colors.{mode}.separatorAlpha es número como en QML", fails)

    check(t["dark"] is True, "dark top-level (espejo QML)", fails)
    check(t["inactive"] == "#DDDDDD", "inactive top-level = #DDD (§2.5)", fails)
    check(t["fontFamily"] == "Inter", "fontFamily top-level (espejo QML)", fails)
    check(t["monoFamily"] == "JetBrains Mono", "monoFamily top-level (espejo QML)", fails)

    r = t["radii"]
    check(r["windowNoToolbar"] == 16, "radio ventana sin toolbar = 16 (§2.3)", fails)
    check(r["windowToolbar"] == 26, "radio ventana con toolbar = 26 (§2.3)", fails)

    for mode, exp in (("light", ("#FF5F57", "#FEBC2E", "#28C840")),
                      ("dark", ("#FF5F57", "#FEBC2E", "#28C840"))):
        c = t["colors"][mode]
        check((c["trafficRed"], c["trafficYellow"], c["trafficGreen"]) == exp,
              f"traffic {mode} = semáforos §3", fails)

    m = t["motion"]
    check((m["tInstant"], m["tQuick"], m["tNormal"], m["tModal"]) == (150, 250, 350, 350),
          "motion 150/250/350/350 (§2.5)", fails)
    check(m["mcSpaces"] == [400, 500], "motion mcSpaces 400-500 (§2.5)", fails)
    check(m["curve"] == "cubic-bezier(0.25,0.1,0.25,1)",
          "motion.curve en JSON y QML (§2.5)", fails)

    g = t["glass"]
    check("dock" not in g and "slab" not in g,
          "glass plano como en QML (sin objetos dock/slab)", fails)
    check(g["sidebarToolbarTint"] == "medium",
          "glass sidebar/toolbar tint medio, sin color custom (§2.4)", fails)
    check(g["sidebarScrollEdgeBlur"] is True,
          "glass sidebar scroll-edge blur (§2.4)", fails)

    meta = t["_meta"]
    for p in ("glass.dockBlurPxEq", "motion.dockAutohide", "type.eyebrow.lineHeight"):
        check(p in meta["_inferred"], f"_inferred contiene {p}", fails)

    for mode in ("light", "dark"):
        c = t["colors"][mode]
        bg = c["bg"]
        l2 = blend(c["label2"], bg, c["label2Alpha"])
        check(contrast(c["label"], bg) >= 4.5, f"WCAG label/bg {mode} ≥4.5:1", fails)
        check(contrast(l2, bg) >= 3.0, f"WCAG label2/bg {mode} ≥3:1", fails)
        check(contrast(c["accent"], bg) >= 3.0, f"WCAG accent/bg {mode} ≥3:1", fails)

    print("RESULT:", "PASS" if not fails else f"FAIL ({len(fails)})")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
