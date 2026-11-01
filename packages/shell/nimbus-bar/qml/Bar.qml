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
import "."

Window {
    id: root
    // F3-T13: preset ~/.config/nimbus-bar/preset.json vía `barPresetJson`
    // (main.cpp; "{}" si ausente/inválido). Sin valores mágicos: cada
    // lectura cae al valor previo del fichero (contrato §3 / tokens).
    property var preset: {
        try {
            return JSON.parse(barPresetJson);
        } catch (e) {
            return {};
        }
    }
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
    // Holder invisible para applyPresetOrder: re-anexar un hijo a su
    // MISMO padre es no-op en Qt (no reordena); se mueven aquí primero.
    Item {
        id: orderHolder
        visible: false
    }
    // Ganchos de diagnóstico (verificación --dump-preset, F3-T13).
    property string presetOrderApplied: ""
    property string presetOrderError: ""
    function applyPresetOrder() {
        // Reordena rightBox según preset.icons.order: todos los iconos
        // pasan por orderHolder y vuelven en la secuencia deseada (los
        // no listados, al final en orden canónico). Bloque síncrono: sin
        // fotograma intermedio. (Los hijos anclan a rightBox: sin TypeErrors.)
        try {
            var order = preset.icons ? preset.icons.order : undefined;
            if (!Array.isArray(order) || order.length === 0)
                return;
            var canon = ["wifi", "bluetooth", "controlcenter", "battery", "tray", "clock"];
            var byId = {
                "wifi": wifiItem,
                "bluetooth": btItem,
                "controlcenter": ccButton,
                "battery": batteryItem,
                "tray": tray,
                "clock": clock
            };
            var seq = [];
            for (var i = 0; i < order.length; ++i) {
                if (byId[order[i]] && seq.indexOf(order[i]) < 0)
                    seq.push(order[i]);
            }
            for (var c = 0; c < canon.length; ++c) {
                if (seq.indexOf(canon[c]) < 0 && byId[canon[c]])
                    seq.push(canon[c]);
            }
            for (var m = 0; m < seq.length; ++m)
                byId[seq[m]].parent = orderHolder;
            for (var b = 0; b < seq.length; ++b)
                byId[seq[b]].parent = rightBox;
            presetOrderApplied = seq.join(",");
        } catch (e) {
            presetOrderError = "" + e;
            console.warn("preset: orden no aplicado (" + e + ")");
        }
    }
    property string clockFormat: pStr("clock", "format", "HH:mm")
    width: Screen.width
    height: pNum("bar", "height", 24)
    visible: true
    visibility: Window.Windowed
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    title: "nimbus-bar"

    LayerShellQt.Window.anchors: LayerShellQt.Window.AnchorTop | LayerShellQt.Window.AnchorLeft | LayerShellQt.Window.AnchorRight
    LayerShellQt.Window.exclusionZone: root.height
    LayerShellQt.Window.layer: LayerShellQt.Window.LayerTop
    LayerShellQt.Window.keyboardInteractivity: LayerShellQt.Window.KeyboardInteractivityNone
    LayerShellQt.Window.scope: "nimbus-bar"
    LayerShellQt.Window.activateOnShow: false

    // Fondo glass oscuro. Alfa del preset [INFERIDO]: medir en VM (A1/A4).
    Rectangle {
        id: bg
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, pNum("bar", "bgAlpha", 0.55))
    }
    // Hairline inferior 1px (contrato §2.1 separator dark) [HIG].
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Qt.rgba(0.22, 0.22, 0.23, pNum("bar", "hairlineAlpha", 0.6))
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
            width: 16
            height: 16
            radius: 4
            anchors.verticalCenter: parent.verticalCenter
            color: NimbusTokens.colors(NimbusTokens.dark).accent
            objectName: "appleLogo"
            Text {
                anchors.centerIn: parent
                text: "N"
                font.family: NimbusTokens.fontFamily
                font.pixelSize: 11
                font.weight: 700
                color: "white"
            }
            MouseArea {
                anchors.fill: parent
                onClicked: appleMenu.toggle()
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
    Component.onCompleted: {
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

    Row {
        id: rightBox
        objectName: "rightBox"
        anchors.right: parent.right
        anchors.rightMargin: pNum("bar", "marginRight", 12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: pNum("bar", "spacingRight", 12)
        // Placeholders extras 22pt (menús reales en F3-T04/T05).
        Text {
            id: wifiItem
            objectName: "wifiItem"
            visible: !pHidden("wifi")
            anchors.verticalCenter: rightBox.verticalCenter
            text: "Wi-Fi"
            font.family: NimbusTokens.fontFamily
            font.pixelSize: NimbusTokens.type.t12.size
            color: NimbusTokens.colors(NimbusTokens.dark).label
            Accessible.name: "Wi-Fi (placeholder)"
        }
        Text {
            id: btItem
            objectName: "btItem"
            visible: !pHidden("bluetooth")
            anchors.verticalCenter: rightBox.verticalCenter
            text: "BT"
            font.family: NimbusTokens.fontFamily
            font.pixelSize: NimbusTokens.type.t12.size
            color: NimbusTokens.colors(NimbusTokens.dark).label
            Accessible.name: "Bluetooth (placeholder)"
        }
        // Batería dibujada (sin iconos externos).
        // F3-T05: botón CC propio (dos toggles, sin activos externos).
        Item {
            id: ccButton
            visible: !pHidden("controlcenter")
            width: 22
            height: 16
            anchors.verticalCenter: rightBox.verticalCenter
            Accessible.name: "Centro de control"
            objectName: "ccButton"
            Column {
                anchors.centerIn: parent
                spacing: 2
                Rectangle {
                    width: 16
                    height: 6
                    radius: 3
                    color: Qt.rgba(1, 1, 1, 0.85)
                    Rectangle {
                        x: 9
                        width: 6
                        height: 6
                        radius: 3
                        color: NimbusTokens.colors(NimbusTokens.dark).accent
                    }
                }
                Rectangle {
                    width: 16
                    height: 6
                    radius: 3
                    color: Qt.rgba(1, 1, 1, 0.85)
                    Rectangle {
                        x: 1
                        width: 6
                        height: 6
                        radius: 3
                        color: NimbusTokens.colors(NimbusTokens.dark).accent
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: cc.toggle()
            }
        }
        Item {
            id: batteryItem
            objectName: "batteryItem"
            visible: !pHidden("battery")
            width: 26
            height: 12
            anchors.verticalCenter: rightBox.verticalCenter
            Accessible.name: "Batería (placeholder)"
            Rectangle {
                anchors.fill: parent
                radius: 3
                color: "transparent"
                border.color: NimbusTokens.colors(NimbusTokens.dark).label
                border.width: 1
                opacity: 0.6
            }
            Rectangle {
                x: 2
                y: 2
                width: 18
                height: 8
                radius: 1.5
                color: NimbusTokens.colors(NimbusTokens.dark).label
            }
        }
        // F3-T07: system tray SNI (antes del reloj).
        StatusArea {
            id: tray
            objectName: "tray"
            visible: !pHidden("tray")
            anchors.verticalCenter: rightBox.verticalCenter
            autoOpenRow: trayOpenMenu
        }
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
            MouseArea {
                anchors.fill: parent
                onClicked: cal.toggle()
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
