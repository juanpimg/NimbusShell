import "."
// Bar.qml — barra superior Nimbus 24pt (F3-T03, R-TOPBAR-LAYER).
// Contrato §3 [HIG]: menu bar 24pt, extras 22pt, fuente ~13pt [INFERIDO].
// Layer-shell: top, anclas Left/Top/Right, exclusiveZone 24,
// scope "nimbus-bar", sin teclado, capa Top, sin decoración.
// Tokens vía singleton NimbusTokens (copia md5-idéntica de
// packages/themes/nimbus-tokens/NimbusTokens.qml; sin valores duplicados).
import QtQuick
import QtQuick.Window
// Alias obligatorio: sin `as`, `Window` colisiona con el tipo no-creable
// org.kde.layershell/Window y la creación falla ("Type cannot be created").
import org.kde.layershell as LayerShellQt

Window {
    id: root

    // F3-T13: preset ~/.config/nimbus-bar/preset.json vía `barPresetJson`
    // (main.cpp; "{}" si ausente/inválido). Sin valores mágicos: cada
    // lectura cae al valor previo del fichero (contrato §3 / tokens).
    property var preset: {
        try {
            return JSON.parse(barPresetJson);
        } catch (e) {
            return {
            };
        }
    }
    // Ganchos de diagnóstico (verificación --dump-preset, F3-T13).
    property string presetOrderApplied: ""
    property string presetOrderError: ""
    property string clockFormat: pStr("clock", "format", "ddd d MMM HH:mm")

    function pNum(section, key, fb) {
        var s = preset[section];
        if (s === undefined || s[key] === undefined)
            return fb;

        var n = Number(s[key]);
        return isNaN(n) ? fb : n;
    }

    function pStr(section, key, fb) {
        var s = preset[section];
        if (s === undefined || typeof s[key] !== "string" || s[key] === "")
            return fb;

        return s[key];
    }

    function pHidden(iconId) {
        var icons = preset.icons;
        if (icons === undefined || !Array.isArray(icons.hidden))
            return false;

        return icons.hidden.indexOf(iconId) >= 0;
    }

    function applyPresetOrder() {
        // Reordena rightBox según preset.icons.order: todos los iconos
        // pasan por orderHolder y vuelven en la secuencia deseada (los
        // no listados, al final en orden canónico). Bloque síncrono: sin
        // fotograma intermedio. (Los hijos anclan a rightBox: sin TypeErrors.)
        try {
            var order = preset.icons ? preset.icons.order : undefined;
            var canon = ["wifi", "bluetooth", "controlcenter", "battery", "tray", "spotlight", "clock"];
            var byId = {
                "wifi": wifiItem,
                "bluetooth": btItem,
                "controlcenter": ccButton,
                "battery": batteryItem,
                "tray": tray,
                "spotlight": spotlightItem,
                "clock": clock
            };
            var seq = [];
            if (Array.isArray(order)) {
                for (var i = 0; i < order.length; ++i) {
                    if (byId[order[i]] && seq.indexOf(order[i]) < 0)
                        seq.push(order[i]);

                }
            }
            // Los iconos que el preset no menciona se insertan en su
            // posición canónica (no al final): Spotlight va antes del reloj
            // (contrato §3), aunque el preset sea antiguo o no exista.
            for (var c = 0; c < canon.length; ++c) {
                if (!byId[canon[c]] || seq.indexOf(canon[c]) >= 0)
                    continue;

                var pos = seq.length;
                for (var n = c + 1; n < canon.length; ++n) {
                    var idx = seq.indexOf(canon[n]);
                    if (idx >= 0) {
                        pos = idx;
                        break;
                    }
                }
                seq.splice(pos, 0, canon[c]);
            }
            for (var m = 0; m < seq.length; ++m) byId[seq[m]].parent = orderHolder
            for (var b = 0; b < seq.length; ++b) byId[seq[b]].parent = rightBox
            presetOrderApplied = seq.join(",");
        } catch (e) {
            presetOrderError = "" + e;
            console.warn("preset: orden no aplicado (" + e + ")");
        }
    }

    width: Screen.width
    height: pNum("bar", "height", 24)
    visible: false
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    title: "nimbus-bar"
    LayerShellQt.Window.anchors: LayerShellQt.Window.AnchorTop | LayerShellQt.Window.AnchorLeft | LayerShellQt.Window.AnchorRight
    LayerShellQt.Window.exclusionZone: root.height
    LayerShellQt.Window.layer: LayerShellQt.Window.LayerTop
    LayerShellQt.Window.keyboardInteractivity: LayerShellQt.Window.KeyboardInteractivityNone
    LayerShellQt.Window.scope: "nimbus-bar"
    LayerShellQt.Window.activateOnShow: false
    Component.onCompleted: {
        // F11-T03: acento configurable + sync inicial dark desde kdeglobals
        // (CC.refresh lee ColorScheme y reescribe NimbusTokens.dark).
        NimbusTokens.accentCustom = typeof customAccent !== "undefined" ? customAccent : "";
        cc.refresh();
        // F3-T13: orden de iconos del preset.
        applyPresetOrder();
        if (demoMenu)
            appleMenu.open();

        if (demoCC || openCC)
            cc.open();

        if (demoCalendar)
            cal.open();

        if (demoOsd)
            osd.show(demoOsdKind, demoOsdValue);

    }

    // Holder invisible para applyPresetOrder: re-anexar un hijo a su
    // MISMO padre es no-op en Qt (no reordena); se mueven aquí primero.
    Item {
        id: orderHolder

        visible: false
    }

    // Fondo glass oscuro. Alfa del preset [INFERIDO]: medir en VM (A1/A4).
    Rectangle {
        id: bg

        anchors.fill: parent
        // F11-T03 color (dark/light) + F3-T13 alpha del preset.
        color: {
            var c = NimbusTokens.barBg(NimbusTokens.dark);
            return Qt.rgba(c.r, c.g, c.b, pNum("bar", "bgAlpha", c.a));
        }
    }

    // Hairline inferior 1px (contrato §2.1 separator dark) [HIG].
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        // F11-T03 color + F3-T13 alpha del preset.
        color: {
            var c = NimbusTokens.hairline(NimbusTokens.dark);
            return Qt.rgba(c.r, c.g, c.b, pNum("bar", "hairlineAlpha", c.a));
        }
    }

    Row {
        id: leftBox

        anchors.left: parent.left
        anchors.leftMargin: pNum("bar", "marginLeft", 12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: pNum("bar", "spacingLeft", 8)

        // Logo "N" propio (arte Nimbus, sin activos Apple).
        // F3-T04: clic abre/cierra el menú Apple.
        Rectangle {
            id: logo

            width: 18
            height: 20
            radius: 5
            anchors.verticalCenter: parent.verticalCenter
            // Menú principal: glifo N propio monocromo (sin activos Apple).
            color: logoArea.pressed ? NimbusTokens.pressedFill(NimbusTokens.dark) : logoArea.containsMouse ? NimbusTokens.hoverFill(NimbusTokens.dark) : "transparent"
            objectName: "appleLogo"
            border.color: NimbusTokens.accentColor(NimbusTokens.dark)
            border.width: logoArea.activeFocus ? NimbusTokens.states.focusRingPx : 0

            Text {
                anchors.centerIn: parent
                text: "N"
                font.family: NimbusTokens.fontFamily
                font.pixelSize: 15
                font.weight: 700
                color: NimbusTokens.colors(NimbusTokens.dark).label
            }

            MouseArea {
                id: logoArea

                anchors.fill: parent
                hoverEnabled: true
                activeFocusOnTab: true
                onClicked: appleMenu.toggle()
                Keys.onReturnPressed: appleMenu.toggle()
            }

        }

        Text {
            visible: !appMenu.hasMenu
            anchors.verticalCenter: parent.verticalCenter
            // F3-T06: sin menú global (GTK/in-window, R-GTK) se muestra el
            // nombre de la app activa en negrita ("Nimbus" si no hay ninguna).
            text: appMenu.appName
            font.family: NimbusTokens.fontFamily
            font.pixelSize: NimbusTokens.type.t13b.size
            font.weight: NimbusTokens.type.t13b.weight
            color: NimbusTokens.colors(NimbusTokens.dark).label
        }
        // F3-T06: menú global Qt de la app activa (nombre bold + items).

        GlobalMenu {
            id: globalMenu

            visible: appMenu.hasMenu
            anchors.verticalCenter: parent.verticalCenter
            demo: demoAppmenu
        }

    }

    // F3-T04: menú Apple (popup layer-shell propio en Menu.qml).
    // demoMenu lo abre al arrancar (flag --demo-menu, solo UI nested).
    Menu {
        id: appleMenu

        demo: demoMenu
    }

    // F3-T05: Control Center anclado al icono CC (derecha).
    ControlCenter {
        id: cc

        demo: demoCC
    }

    // F3-T08: calendario anclado al reloj (derecha).
    Calendar {
        id: cal

        demo: demoCalendar
    }

    // F3-T10: OSD volumen/brillo in-situ bajo la barra (contrato §3).
    OSD {
        id: osd

        objectName: "osdRoot"
        demo: demoOsd
        popupWidth: root.pNum("osd", "width", 280)
        popupHeight: root.pNum("osd", "height", 56)
        timeoutMs: root.pNum("osd", "timeoutMs", 1500)
    }

    // F3-T12: banners de notificación (servidor FDO en la barra,
    // R-NOTIF-SERVER). Sin servidor la lista está vacía y no se muestra.
    NotificationCenter {
        id: notifCenter

        objectName: "notifCenter"
    }

    Row {
        id: rightBox

        objectName: "rightBox"
        anchors.right: parent.right
        anchors.rightMargin: pNum("bar", "marginRight", 12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: pNum("bar", "spacingRight", 12)

        // Batería dibujada (sin iconos externos).
        // F3-T05: botón CC propio (dos toggles, sin activos externos).
        // F3-T05: extras dibujados con geometría propia (sin activos Apple).
        // Orden macOS (contrato §3): Wi-Fi · Bluetooth · CC · batería ·
        // tray · Spotlight · reloj. applyPresetOrder lo fija en runtime.
        StatusArea {
            id: tray

            objectName: "tray"
            visible: !pHidden("tray")
            anchors.verticalCenter: rightBox.verticalCenter
            autoOpenRow: trayOpenMenu
        }

        Item {
            id: batteryItem

            objectName: "batteryItem"
            visible: !pHidden("battery") && battery.present
            width: 26
            height: 12
            anchors.verticalCenter: rightBox.verticalCenter
            Accessible.name: "Batería " + battery.charge + "%"

            Rectangle {
                anchors.fill: parent
                radius: 3
                color: "transparent"
                border.color: NimbusTokens.colors(NimbusTokens.dark).label
                border.width: 1
                opacity: 0.85
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width + 1
                width: 2
                height: 5
                radius: 1
                color: NimbusTokens.colors(NimbusTokens.dark).label
                opacity: 0.85
            }

            Rectangle {
                x: 2
                y: 2
                width: Math.round(20 * battery.charge / 100)
                height: 8
                radius: 1.5
                color: battery.charging ? NimbusTokens.accentColor(NimbusTokens.dark) : NimbusTokens.colors(NimbusTokens.dark).label
            }

        }

        Item {
            id: wifiItem

            objectName: "wifiItem"
            visible: !pHidden("wifi")
            width: 16
            height: 16
            anchors.verticalCenter: rightBox.verticalCenter
            Accessible.name: "Wi-Fi"

            Canvas {
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = NimbusTokens.colors(NimbusTokens.dark).label;
                    ctx.fillStyle = ctx.strokeStyle;
                    ctx.lineWidth = 1.6;
                    ctx.lineCap = "round";
                    var cx = 8, cy = 12;
                    for (var i = 1; i <= 3; ++i) {
                        ctx.beginPath();
                        ctx.arc(cx, cy, 2.2 + i * 2.6, Math.PI * 1.2, Math.PI * 1.8);
                        ctx.stroke();
                    }
                    ctx.beginPath();
                    ctx.arc(cx, cy, 1.05, 0, Math.PI * 2);
                    ctx.fill();
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: cc.toggle()
            }

        }

        Item {
            id: btItem

            objectName: "btItem"
            visible: !pHidden("bluetooth")
            width: 16
            height: 16
            anchors.verticalCenter: rightBox.verticalCenter
            Accessible.name: "Bluetooth"

            Canvas {
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = NimbusTokens.colors(NimbusTokens.dark).label;
                    ctx.lineWidth = 1.5;
                    ctx.lineJoin = "round";
                    ctx.lineCap = "round";
                    ctx.beginPath();
                    ctx.moveTo(6, 2);
                    ctx.lineTo(11, 6);
                    ctx.lineTo(2, 12);
                    ctx.moveTo(2, 4);
                    ctx.lineTo(11, 10);
                    ctx.lineTo(6, 14);
                    ctx.moveTo(6, 2);
                    ctx.lineTo(6, 14);
                    ctx.stroke();
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: cc.toggle()
            }

        }

        Item {
            id: spotlightItem

            objectName: "spotlightItem"
            width: 16
            height: 16
            anchors.verticalCenter: rightBox.verticalCenter
            Accessible.name: "Spotlight"

            Canvas {
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = NimbusTokens.colors(NimbusTokens.dark).label;
                    ctx.lineWidth = 1.6;
                    ctx.lineCap = "round";
                    ctx.beginPath();
                    ctx.arc(7, 7, 4.4, 0, Math.PI * 2);
                    ctx.moveTo(10.4, 10.4);
                    ctx.lineTo(14, 14);
                    ctx.stroke();
                }
            }

            MouseArea {
                anchors.fill: parent
                activeFocusOnTab: true
                onClicked: runner.run("qdbus6 org.nimbus.Spotlight /Spotlight org.nimbus.Spotlight.toggle")
                Keys.onReturnPressed: runner.run("qdbus6 org.nimbus.Spotlight /Spotlight org.nimbus.Spotlight.toggle")
            }

        }

        Item {
            id: ccButton

            visible: !pHidden("controlcenter")
            width: 22
            height: 16
            anchors.verticalCenter: rightBox.verticalCenter
            Accessible.name: "Centro de control"
            objectName: "ccButton"

            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: 6
                color: "transparent"
                border.color: NimbusTokens.accentColor(NimbusTokens.dark)
                border.width: ccArea.activeFocus ? NimbusTokens.states.focusRingPx : 0
            }

            Column {
                anchors.centerIn: parent
                spacing: 2

                Rectangle {
                    width: 16
                    height: 6
                    radius: 3
                    color: NimbusTokens.colors(NimbusTokens.dark).label
                    opacity: 0.85

                    Rectangle {
                        x: 9
                        width: 6
                        height: 6
                        radius: 3
                        color: NimbusTokens.accentColor(NimbusTokens.dark)
                    }

                }

                Rectangle {
                    width: 16
                    height: 6
                    radius: 3
                    color: NimbusTokens.colors(NimbusTokens.dark).label
                    opacity: 0.85

                    Rectangle {
                        x: 1
                        width: 6
                        height: 6
                        radius: 3
                        color: NimbusTokens.accentColor(NimbusTokens.dark)
                    }

                }

            }

            MouseArea {
                id: ccArea

                anchors.fill: parent
                activeFocusOnTab: true
                onClicked: cc.toggle()
                Keys.onReturnPressed: cc.toggle()
            }

        }
        // F3-T07: system tray SNI (antes del reloj).

        Text {
            id: clock

            visible: !pHidden("clock")
            anchors.verticalCenter: rightBox.verticalCenter
            font.family: NimbusTokens.fontFamily
            font.pixelSize: NimbusTokens.type.t13.size
            color: NimbusTokens.colors(NimbusTokens.dark).label
            Accessible.name: "Reloj"
            objectName: "clock"

            // F3-T08: clic abre/cierra el calendario.
            // F11-T03: foco teclado visible (anillo accent 2px).
            MouseArea {
                id: clockArea

                anchors.fill: parent
                activeFocusOnTab: true
                onClicked: cal.toggle()
                Keys.onReturnPressed: cal.toggle()
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -2
                radius: 4
                color: "transparent"
                border.color: NimbusTokens.accentColor(NimbusTokens.dark)
                border.width: clockArea.activeFocus ? NimbusTokens.states.focusRingPx : 0
            }

            Timer {
                interval: 1000
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: clock.text = Qt.formatDateTime(new Date(), clockFormat)
            }

        }

    }

}
