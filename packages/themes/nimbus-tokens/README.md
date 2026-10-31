# nimbus-tokens — tokens Tahoe desde contrato §2

Fuente única: `docs/design/tahoe-design-contract.md` §2 (R-TAHOE-TOKENS).
Prohíbe valores mágicos fuera del singleton.

## Mapa token → contrato

| Token | Contrato | Confianza |
|---|---|---|
| `colors().label/label2/label3/label4/separator` | §2.1 tabla | [HIG] |
| `colors().accent/success/destructive/warning` | §2.1 tabla | [HIG] |
| `colors().bg/bgElevated/bg2` | §2.1 tabla | [HIG] |
| `colors().trafficRed/Yellow/Green` | §3 semáforos `#FF5F57/#FEBC2E/#28C840` | [HIG] |
| `inactive #DDD` | §2.5 inactivo gris | [HIG] |
| `type.t11..t28`, `eyebrow` | §2.2 tabla | [HIG] |
| `fontFamily Inter`, `monoFamily JetBrains Mono` | §2.2 | [HIG] |
| `spacing` escala 4..32, marginWindow 20, padContent 16 | §2.3 | [HIG] |
| `spacing.toolbarH 52, sidebarW 240, row 28, readMax 672` | §2.3 | [HIG/MEDIDO] |
| `radii rSm 8, rMd 10-12, rLg 20` | §2.3 | [HIG] |
| `radii.windowNoToolbar 16, windowToolbar 26` | §2.3 Lapcat, concéntrico | [HIG] |
| `controls.btnH 28/32/36, hitMin 24, hitTarget 32/44` | §2.3 | [HIG] |
| `glass.menuSatMax, dockAdapt/sat/grain, slab*, popoverHairline*` | §2.4 | [MEDIDO] |
| `glass.dockBlurPxEq 15-25` | §2.4 Dock | [INFERIDO] |
| `motion.*` (150/250/350, curva, exit×0.7, fade 150) | §2.5 | [HIG] |
| `motion.dockAutohide 500` | §2.5 | [INFERIDO] |
| `states.*`, `a11y.*` (4.5:1/3:1, objetivo 7:1, reflujo 135%) | §2.5 | [HIG] |

## Uso QML

```qml
import "packages/themes/nimbus-tokens" as Tokens  // vía qmldir (singleton NimbusTokens)
// o registra la ruta con qmlimportscanner / QML_IMPORT_PATH
Rectangle {
    color: NimbusTokens.colors(NimbusTokens.dark).bgElevated
    radius: NimbusTokens.radii.windowToolbar
    Text { text: "Hola"; font.family: NimbusTokens.fontFamily; font.pixelSize: NimbusTokens.type.t13.size }
}
```

## Uso JSON (scripts/KCM)

`tokens.json` es espejo exacto del QML: `python3 -c "import json; t=json.load(open('tokens.json')); print(t['colors']['dark']['accent'])"`.
