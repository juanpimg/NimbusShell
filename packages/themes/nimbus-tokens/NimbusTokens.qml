pragma Singleton
import QtQuick

// NimbusTokens — fuente única de tokens Tahoe (contrato §2, R-TAHOE-TOKENS).
// Espejo QML de tokens.json. Sin valores mágicos fuera de este singleton.
QtObject {
    // §2.1 + §2.5: modo + gris inactivo [HIG]
    property bool dark: true
    readonly property string inactive: "#DDDDDD" // [HIG] §2.5 inactivo/semáforos gris

    // §2.1 color semántico [HIG]. label2/3/4/separator: base opaca + alfa (QML los compone).
    // (firma sin tipos: compatible con qmllint era-Qt5 y Qt6)
    function colors(isDark) {
        return isDark ? _dark : _light;
    }
    readonly property var _light: ({
        // §2.1 tabla light [HIG]
        label: "#000000", label2: "#3C3C43", label2Alpha: 0.6,
        label3: "#3C3C43", label3Alpha: 0.3, label4: "#3C3C43", label4Alpha: 0.18,
        separator: "#C6C6C8", separatorAlpha: 0.29,
        accent: "#007AFF", success: "#34C759", destructive: "#FF3B30", warning: "#FF9500",
        bg: "#FFFFFF", bgElevated: "#FFFFFF", bg2: "#F2F2F7",
        trafficRed: "#FF5F57", trafficYellow: "#FEBC2E", trafficGreen: "#28C840" // [HIG] §3
    })
    readonly property var _dark: ({
        // §2.1 tabla dark [HIG]
        label: "#FFFFFF", label2: "#EBEBF5", label2Alpha: 0.6,
        label3: "#EBEBF5", label3Alpha: 0.3, label4: "#EBEBF5", label4Alpha: 0.18,
        separator: "#38383A", separatorAlpha: 0.6,
        accent: "#0A84FF", success: "#30D158", destructive: "#FF453A", warning: "#FF9F0A",
        bg: "#000000", bgElevated: "#2C2C2E", bg2: "#1C1C1E",
        trafficRed: "#FF5F57", trafficYellow: "#FEBC2E", trafficGreen: "#28C840" // [HIG] §3
    })

    // §2.2 tipografía Inter [HIG]; tracking en em, lineHeight en px
    readonly property string fontFamily: "Inter" // [HIG] §2.2
    readonly property string monoFamily: "JetBrains Mono" // [HIG] §2.2 código
    readonly property var type: ({
        t11: { size: 11, weight: 500, tracking: 0.01, lineHeight: 15 }, // [HIG]
        t12: { size: 12, weight: 400, tracking: 0.0, lineHeight: 15 }, // [HIG]
        t13: { size: 13, weight: 400, tracking: -0.006, lineHeight: 16 }, // [HIG]
        t13b: { size: 13, weight: 700, tracking: -0.006, lineHeight: 16 }, // [HIG]
        t15: { size: 15, weight: 400, weightEmph: 600, tracking: -0.015, lineHeight: 20 }, // [HIG]
        t17: { size: 17, weight: 400, weightEmph: 700, tracking: -0.025, lineHeight: 22 }, // [HIG]
        t22: { size: 22, weight: 400, weightEmph: 700, tracking: -0.02, lineHeight: 26 }, // [HIG]
        t28: { size: 28, weight: 600, tracking: -0.02, lineHeight: 34 }, // [HIG]
        eyebrow: { size: 11, weight: 600, upper: true, tracking: 0.08, lineHeight: 15 } // [HIG] todo salvo lineHeight; lineHeight 15 [INFERIDO] (contrato §2.2: "—")
    })

    // §2.3 spacing [HIG]; toolbarH/sidebarW/row/readMax [HIG/MEDIDO]
    readonly property var spacing: ({
        s4: 4, s8: 8, s12: 12, s16: 16, s20: 20, s24: 24, s32: 32,
        marginWindow: 20, padContent: 16, toolbarH: 52, sidebarW: 240, row: 28,
        readMax: 672, gapBtnMin: 8, gapBtnMax: 12
    })

    // §2.3 radios [HIG]; ventana 16/26 concéntrico (Lapcat)
    readonly property var radii: ({
        rSm: 8, rMd: 10, rMdMax: 12, rLg: 20, windowNoToolbar: 16, windowToolbar: 26
    })

    // §2.3 controles [HIG]: btn macOS 28; floor Nimbus ≥24 WCAG; objetivo 32-44
    readonly property var controls: ({
        btnH: [28, 32, 36], hitMin: 24, hitTarget: [32, 44]
    })

    // §2.4 glass: efecto Apple [HIG]; números Nimbus [MEDIDO]; blur Dock [INFERIDO]
    readonly property var glass: ({
        menuSatMax: 1.4, // [HIG] sat ≤1.4 menu bar
        dockBlurPxEq: [15, 25], // [INFERIDO] blur ~15-25px eq.
        dockAdapt: [0.78, 1.28], // [MEDIDO] adapt por luminancia
        dockSat: 1.25, // [MEDIDO]
        dockGrain: [0.006, 0.03], // [MEDIDO] grano mono
        slabBlurPx: 1.5, slabThickness: 16, slabSnellN: 1.5, // [MEDIDO] slab pequeño
        slabDispersion: 0.06, slabMagnify: 0.05, // [MEDIDO]
        popoverHairlineLight: 0.12, popoverHairlineDark: 0.16, // [MEDIDO] hairline Canvas
        sidebarToolbarTint: "medium", // [HIG] §2.4 tint medio, sin color custom en bars
        sidebarScrollEdgeBlur: true // [HIG] §2.4 deja pasar scroll (scroll-edge blur)
        // Reduce Transparency vive en F8-T05 (un solo interruptor KWin+QML);
        // su fallback sólido es bgElevated, ya tokenizado — sin token nuevo aquí.
    })

    // §2.5 motion [HIG]; dockAutohide [INFERIDO]
    readonly property var motion: ({
        tInstant: 150, tQuick: 250, tNormal: 350, tModal: 350,
        mcSpaces: [400, 500], dockAutohide: 500, // dockAutohide [INFERIDO]
        curve: "cubic-bezier(0.25,0.1,0.25,1)", // [HIG] §2.5
        exitFactor: 0.7, reduceMotionFade: 150
    })

    // §2.5 estados [HIG]
    readonly property var states: ({
        disabledOpacity: [0.3, 0.5], focusRingPx: 2, focusContrast: 3.0
    })

    // §2.5 a11y [HIG]: 4.5:1 pequeño / 3:1 grande / objetivo 7:1 / reflujo 135%
    readonly property var a11y: ({
        contrastSmall: 4.5, contrastLarge: 3.0, contrastTarget: 7.0, reflowPct: 135
    })
}
