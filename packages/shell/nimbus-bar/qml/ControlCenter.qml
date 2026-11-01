// ControlCenter.qml — popup anclado al icono CC (F3-T05, patrón Menu.qml).
// Scrim fullscreen + popup derecha (ancho 300). Estados reales al abrir vía
// runner.query(tag) + Timer de refresco 5s. Sin toggles destructivos en demo.
import QtQuick
import QtQuick.Controls
import org.kde.layershell as LayerShellQt

Item {
    id: root
    property bool opened: false
    property bool demo: false
    property string wifi: "—"
    property bool wifiOn: false
    property string bt: "—"
    property bool btOn: false
    property string dnd: "—"
    property bool dndOn: false
    property string theme: "—"
    property bool darkOn: true
    property string batt: "—"
    property real vol: -1
    property real bri: -1
    function toggle() {
        opened ? close() : open();
    }
    function open() {
        opened = true;
        refresh();
    }
    function close() {
        opened = false;
    }
    function refresh() {
        // F11-T03: el tema (kdeglobals → NimbusTokens.dark) se lee SIEMPRE,
        // también en demo: es solo lectura y toda la barra reacciona a dark.
        runner.query("kreadconfig6 --file kdeglobals --group KDE --key ColorScheme 2>/dev/null || echo —", "theme");
        if (demo)
            return; // demo: solo UI, sin comandos
        runner.query("nmcli -t -f active,ssid dev wifi 2>/dev/null | grep -m1 '^yes' | cut -d: -f2 || echo —", "wifi");
        runner.query("bluetoothctl show 2>/dev/null | grep -m1 Powered | grep -q yes && echo on || echo off", "bt");
        runner.query("qdbus6 org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications.GetServerInformation 2>/dev/null; qdbus6 org.kde.notificationmanager /NotificationManager org.kde.notificationmanager.doNotDisturb 2>/dev/null || echo —", "dnd");
        runner.query("cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1 || echo —", "batt");
        runner.query("wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo —", "vol");
        runner.query("brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%'", "bri");
    }
    function flip(kind: string) {
        if (demo) {
            console.log("cc: toggle " + kind + " (demo, no ejecutado)");
            return;
        }
        if (kind === "wifi")
            runner.run(wifiOn ? "nmcli radio wifi off" : "nmcli radio wifi on");
        else if (kind === "bt")
            runner.run("bluetoothctl power " + (btOn ? "off" : "on"));
        else if (kind === "theme")
            runner.run(darkOn ? "plasma-apply-colorscheme BreezeLight" : "plasma-apply-colorscheme BreezeDark");
        refresh();
    }
    Connections {
        target: runner
        function onOutputReady(tag: string, out: string) {
            if (tag === "wifiOn")
                root.wifiOn = out.indexOf("habilit") >= 0 || out.trim() === "enabled";
            else if (tag === "wifi")
                root.wifi = out === "" ? "—" : out;
            else if (tag === "bt") {
                root.btOn = out.trim() === "on";
                root.bt = root.btOn ? "on" : "off";
            } else if (tag === "dnd") {
                root.dndOn = out.trim() === "true";
                root.dnd = out.trim() === "" || out.trim() === "—" ? "—" : (root.dndOn ? "on" : "off");
            } else if (tag === "theme") {
                if (out !== "" && out !== "—") {
                    root.darkOn = out.indexOf("Dark") >= 0;
                    root.theme = out;
                    // F11-T03: kdeglobals → token dark; toda la barra reacciona.
                    NimbusTokens.dark = root.darkOn;
                } else {
                    root.theme = "—";
                }
            } else if (tag === "batt")
                root.batt = out === "" ? "—" : out + (out === "—" ? "" : "%");
            else if (tag === "vol") {
                var m = out.match(/([0-9.]+)/);
                root.vol = m ? parseFloat(m[1]) : -1;
            } else if (tag === "bri")
                root.bri = out === "—" || out === "" ? -1 : parseFloat(out) / 100.0;
        }
    }
    Timer {
        interval: 5000
        running: root.opened && !root.demo
        repeat: true
        onTriggered: root.refresh()
    }
    Window {
        id: scrim
        visible: root.opened
        width: Screen.width
        height: Screen.height
        x: 0
        y: 0
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        color: "transparent"
        title: "nimbus-cc-scrim"
        LayerShellQt.Window.layer: LayerShellQt.Window.LayerTop
        LayerShellQt.Window.exclusionZone: 0
        LayerShellQt.Window.keyboardInteractivity: LayerShellQt.Window.KeyboardInteractivityOnDemand
        LayerShellQt.Window.scope: "nimbus-cc-scrim"
        LayerShellQt.Window.activateOnShow: false
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
        Shortcut {
            sequence: "Escape"
            enabled: root.opened
            onActivated: root.close()
        }
    }
    Window {
        id: popup
        visible: root.opened
        width: 300
        height: 380
        x: Screen.width - width - 8
        y: 26
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        color: "transparent"
        title: "nimbus-cc"
        LayerShellQt.Window.layer: LayerShellQt.Window.LayerTop
        LayerShellQt.Window.anchors: LayerShellQt.Window.AnchorTop | LayerShellQt.Window.AnchorRight
        LayerShellQt.Window.exclusionZone: 0
        LayerShellQt.Window.keyboardInteractivity: LayerShellQt.Window.KeyboardInteractivityNone
        LayerShellQt.Window.scope: "nimbus-cc"
        LayerShellQt.Window.activateOnShow: false
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: NimbusTokens.popupBg(NimbusTokens.dark)
            border.color: NimbusTokens.popupBorder(NimbusTokens.dark)
            border.width: 1
            Grid {
                anchors.fill: parent
                anchors.margins: 10
                columns: 2
                spacing: 8
                Repeater {
                    model: [
                        {
                            label: "Wi-Fi",
                            sub: root.wifi,
                            on: root.wifiOn,
                            kind: "wifi",
                            glyph: "W"
                        },
                        {
                            label: "BT",
                            sub: root.bt,
                            on: root.btOn,
                            kind: "bt",
                            glyph: "B"
                        },
                        {
                            label: "No molestar",
                            sub: root.dnd,
                            on: root.dndOn,
                            kind: "dnd",
                            glyph: "D"
                        },
                        {
                            label: "Oscuro",
                            sub: root.theme,
                            on: root.darkOn,
                            kind: "theme",
                            glyph: "O"
                        }
                    ]
                    delegate: Rectangle {
                        width: (300 - 28) / 2
                        height: 64
                        radius: 10
                        // F11-T03: on = accent configurable (selected),
                        // hover/pressed = iluminación, foco = anillo [HIG §2.5].
                        property bool tileOn: modelData.on
                        color: tileArea.pressed || (tileArea.containsMouse && !tileOn) ? NimbusTokens.pressedFill(NimbusTokens.dark) : tileOn ? NimbusTokens.selectedFill(NimbusTokens.dark) : NimbusTokens.hoverFill(NimbusTokens.dark)
                        border.color: NimbusTokens.accentColor(NimbusTokens.dark)
                        border.width: tileArea.activeFocus ? NimbusTokens.states.focusRingPx : 0
                        objectName: "ccTile:" + modelData.label
                        Column {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 2
                            Text {
                                text: modelData.glyph
                                font.pixelSize: 14
                                font.weight: 700
                                color: parent.parent.tileOn ? "white" : NimbusTokens.colors(NimbusTokens.dark).label
                            }
                            Text {
                                text: modelData.label
                                font.pixelSize: 12
                                color: parent.parent.tileOn ? "white" : NimbusTokens.colors(NimbusTokens.dark).label
                            }
                            Text {
                                text: modelData.sub
                                font.pixelSize: 11
                                color: parent.parent.tileOn ? Qt.rgba(1, 1, 1, 0.7) : NimbusTokens.subText(NimbusTokens.dark)
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                        MouseArea {
                            id: tileArea
                            anchors.fill: parent
                            hoverEnabled: true
                            activeFocusOnTab: true
                            onClicked: root.flip(modelData.kind)
                            Keys.onReturnPressed: root.flip(modelData.kind)
                        }
                    }
                }
            }
            Text {
                id: battLine
                x: 12
                y: 296
                text: "Batería " + root.batt
                font.pixelSize: 12
                color: NimbusTokens.colors(NimbusTokens.dark).label
                objectName: "ccBatt"
            }
            Rectangle {
                x: 8
                y: 312
                width: 284
                height: 28
                radius: 6
                color: "transparent"
                border.color: NimbusTokens.accentColor(NimbusTokens.dark)
                border.width: volSlider.activeFocus ? NimbusTokens.states.focusRingPx : 0
            }
            Slider {
                id: volSlider
                x: 12
                y: 316
                width: 276
                from: 0
                to: 1
                value: root.vol < 0 ? 0.5 : root.vol
                enabled: !root.demo && root.vol >= 0
                objectName: "ccVol"
                onMoved: runner.run("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + value.toFixed(2))
            }
            Rectangle {
                x: 8
                y: 344
                width: 284
                height: 28
                radius: 6
                color: "transparent"
                border.color: NimbusTokens.accentColor(NimbusTokens.dark)
                border.width: briSlider.activeFocus ? NimbusTokens.states.focusRingPx : 0
            }
            Slider {
                id: briSlider
                x: 12
                y: 348
                width: 276
                from: 0
                to: 1
                value: root.bri < 0 ? 0.5 : root.bri
                enabled: !root.demo && root.bri >= 0
                objectName: "ccBri"
                onMoved: runner.run("brightnessctl set " + Math.round(value * 100) + "%")
            }
        }
    }
}
