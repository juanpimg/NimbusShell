// ControlCenter.qml — F3-T05 Control Center estilo macOS Tahoe.
// Panel flotante sin fondo opaco: cada módulo es una cápsula de vidrio
// independiente (tinte alfa + hairline + sombra suave). El blur/refracción
// real lo integra el orquestador (F3-T05b); aquí NO hay blur falso.
// Contrato intacto: opened/toggle/open/close, refresh(), flip(kind),
// runner.query tags, señales wifi/bt/dnd/theme/batt/vol/bri, Esc y click-fuera.
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
    property string dnd: dndOn ? "Activado" : "Desactivado"
    property bool dndOn: typeof notifServer !== "undefined" ? notifServer.inhibited : false
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
        // El nombre del esquema sí es fiable si se lee del grupo correcto:
        // NimbusTahoe (oscuro) / NimbusTahoeLight / BreezeDark / BreezeLight.
        runner.query("kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null || echo —", "theme");
        if (demo)
            return; // demo: solo UI, sin comandos
        runner.query("nmcli -t -f active,ssid dev wifi 2>/dev/null | grep -m1 '^yes' | cut -d: -f2 || echo —", "wifi");
        // F3-T05: el badge de Wi-Fi necesita el estado de la radio, no solo el SSID.
        runner.query("nmcli radio wifi 2>/dev/null || echo off", "wifiOn");
        runner.query("bluetoothctl show 2>/dev/null | grep -m1 Powered | grep -q yes && echo on || echo off", "bt");
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
            runner.run(darkOn ? "plasma-apply-colorscheme NimbusTahoeLight" : "plasma-apply-colorscheme NimbusTahoe");
        else if (kind === "dnd") {
            if (typeof notifServer !== "undefined")
                notifServer.inhibited = !notifServer.inhibited;
        }
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
            } else if (tag === "theme") {
                if (out !== "" && out !== "—") {
                    root.theme = out;
                    // "Light" en el nombre = claro; NimbusTahoe = oscuro.
                    root.darkOn = out.indexOf("Light") < 0;
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

    // ── Geometría medida (F3-T05) ────────────────────────────────────────
    // Panel ~360 px; rejilla 2×166 con gap 12; sliders 344×64.
    readonly property int panelW: 356
    readonly property int contentW: 344
    readonly property int gap: 12
    readonly property int cellW: (contentW - gap) / 2
    readonly property int capsuleH: 64
    readonly property int capsuleR: 28
    readonly property int sliderR: 22
    // Vidrio neutro (Tahoe CC es oscuro translúcido en ambos temas).
    readonly property color glassTint: NimbusTokens.dark ? Qt.rgba(0.14, 0.15, 0.18, 0.56) : Qt.rgba(0.10, 0.11, 0.14, 0.46)
    readonly property color glassBorder: Qt.rgba(1, 1, 1, NimbusTokens.dark ? 0.16 : 0.22)
    readonly property color textMain: "#FFFFFF"
    readonly property color textSub: Qt.rgba(1, 1, 1, 0.7)
    readonly property color badgeOff: Qt.rgba(1, 1, 1, 0.18)
    // Tahoe: badge blanco con glifo de acento (no badge de acento).
    readonly property color badgeOn: Qt.rgba(1, 1, 1, 0.92)
    readonly property color accent: NimbusTokens.accentColor(NimbusTokens.dark)
    readonly property string wifiSub: root.wifiOn ? (root.wifi !== "" && root.wifi !== "—" ? root.wifi : "Activado") : "Desactivado"
    readonly property string btSub: root.btOn ? "Activado" : "Desactivado"
    readonly property string dndSub: root.dndOn ? "Activado" : "Desactivado"
    readonly property real battLevel: {
        var n = parseInt(root.batt);
        return isNaN(n) ? 0.75 : Math.max(0, Math.min(1, n / 100));
    }

    // ── Cápsula de vidrio reutilizable ───────────────────────────────────
    // El tinte se queda en alfa 0.46–0.56; nada de relleno opaco. La sombra
    // es una silueta desplazada de baja opacidad (sin blur de fondo).
    component GlassCapsule: Item {
        id: cap
        property real cornerRadius: 28
        property bool focusRing: false
        Rectangle {
            anchors.fill: card
            anchors.margins: -3
            anchors.bottomMargin: -5
            radius: cap.cornerRadius + 3
            color: Qt.rgba(0, 0, 0, 0.22)
        }
        Rectangle {
            id: card
            anchors.fill: parent
            radius: cap.cornerRadius
            color: root.glassTint
            border.width: cap.focusRing ? NimbusTokens.states.focusRingPx : 1
            border.color: cap.focusRing ? root.accent : root.glassBorder
        }
        Rectangle {
            anchors.fill: card
            radius: card.radius
            color: Qt.rgba(1, 1, 1, 0.06)
            visible: hover.hovered
        }
        HoverHandler {
            id: hover
        }
    }

    // ── Iconos dibujados (Canvas; sin glifos de texto) ───────────────────
    component Glyph: Canvas {
        id: glyph
        property string kind: "wifi"
        property color stroke: "#FFFFFF"
        property real level: 0.75
        width: 24
        height: 24
        onKindChanged: requestPaint()
        onStrokeChanged: requestPaint()
        onLevelChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var w = width, h = height, cx = w / 2, cy = h / 2;
            ctx.strokeStyle = glyph.stroke;
            ctx.fillStyle = glyph.stroke;
            ctx.lineWidth = Math.max(1.4, w / 13);
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            if (kind === "wifi") {
                for (var i = 0; i < 3; i++) {
                    var r = w * 0.12 + i * w * 0.14;
                    ctx.beginPath();
                    ctx.arc(cx, h * 0.68, r, Math.PI * 1.22, Math.PI * 1.78);
                    ctx.stroke();
                }
                ctx.beginPath();
                ctx.arc(cx, h * 0.68, Math.max(1.2, w / 18), 0, Math.PI * 2);
                ctx.fill();
            } else if (kind === "bluetooth") {
                var d = w * 0.28;
                ctx.beginPath();
                ctx.moveTo(cx, h * 0.12);
                ctx.lineTo(cx, h * 0.88);
                ctx.moveTo(cx, h * 0.12);
                ctx.lineTo(cx + d, h * 0.34);
                ctx.lineTo(cx - d, h * 0.66);
                ctx.moveTo(cx, h * 0.88);
                ctx.lineTo(cx + d, h * 0.66);
                ctx.lineTo(cx - d, h * 0.34);
                ctx.stroke();
            } else if (kind === "moon") {
                var mr = w * 0.38;
                ctx.beginPath();
                ctx.arc(cx, cy, mr, 0, Math.PI * 2);
                ctx.fill();
                ctx.globalCompositeOperation = "destination-out";
                ctx.beginPath();
                ctx.arc(cx + mr * 0.48, cy - mr * 0.18, mr * 0.92, 0, Math.PI * 2);
                ctx.fill();
                ctx.globalCompositeOperation = "source-over";
            } else if (kind === "battery") {
                var bw = w * 0.82, bh = h * 0.46, bx = (w - bw) / 2, by = (h - bh) / 2, br = h * 0.1;
                ctx.lineWidth = Math.max(1.3, w / 16);
                ctx.beginPath();
                ctx.moveTo(bx + br, by);
                ctx.lineTo(bx + bw - br, by);
                ctx.quadraticCurveTo(bx + bw, by, bx + bw, by + br);
                ctx.lineTo(bx + bw, by + bh - br);
                ctx.quadraticCurveTo(bx + bw, by + bh, bx + bw - br, by + bh);
                ctx.lineTo(bx + br, by + bh);
                ctx.quadraticCurveTo(bx, by + bh, bx, by + bh - br);
                ctx.lineTo(bx, by + br);
                ctx.quadraticCurveTo(bx, by, bx + br, by);
                ctx.stroke();
                ctx.fillRect(bx + bw + 1, by + bh * 0.28, Math.max(1.5, w / 14), bh * 0.44);
                ctx.fillRect(bx + 2, by + 2, Math.max(0, (bw - 4) * Math.max(0, Math.min(1, level))), bh - 4);
            } else if (kind === "sun") {
                var sr = w * 0.2;
                ctx.beginPath();
                ctx.arc(cx, cy, sr, 0, Math.PI * 2);
                ctx.fill();
                for (var j = 0; j < 8; j++) {
                    var a = j * Math.PI / 4;
                    ctx.beginPath();
                    ctx.moveTo(cx + Math.cos(a) * (sr + w * 0.1), cy + Math.sin(a) * (sr + w * 0.1));
                    ctx.lineTo(cx + Math.cos(a) * (sr + w * 0.22), cy + Math.sin(a) * (sr + w * 0.22));
                    ctx.stroke();
                }
            } else if (kind === "speaker") {
                ctx.beginPath();
                ctx.moveTo(w * 0.14, h * 0.38);
                ctx.lineTo(w * 0.3, h * 0.38);
                ctx.lineTo(w * 0.48, h * 0.22);
                ctx.lineTo(w * 0.48, h * 0.78);
                ctx.lineTo(w * 0.3, h * 0.62);
                ctx.lineTo(w * 0.14, h * 0.62);
                ctx.closePath();
                ctx.fill();
                for (var s = 0; s < 2; s++) {
                    ctx.beginPath();
                    ctx.arc(w * 0.47, cy, w * 0.16 + s * w * 0.14, -Math.PI * 0.38, Math.PI * 0.38);
                    ctx.stroke();
                }
            } else if (kind === "music") {
                ctx.beginPath();
                ctx.arc(w * 0.34, h * 0.74, w * 0.11, 0, Math.PI * 2);
                ctx.fill();
                ctx.beginPath();
                ctx.moveTo(w * 0.44, h * 0.72);
                ctx.lineTo(w * 0.44, h * 0.26);
                ctx.lineTo(w * 0.72, h * 0.34);
                ctx.stroke();
            } else if (kind === "play") {
                ctx.beginPath();
                ctx.moveTo(w * 0.38, h * 0.26);
                ctx.lineTo(w * 0.76, h * 0.5);
                ctx.lineTo(w * 0.38, h * 0.74);
                ctx.closePath();
                ctx.fill();
            } else if (kind === "pause") {
                ctx.fillRect(w * 0.36, h * 0.28, w * 0.1, h * 0.44);
                ctx.fillRect(w * 0.56, h * 0.28, w * 0.1, h * 0.44);
            } else if (kind === "prev" || kind === "next") {
                var flip = kind === "next";
                var t1 = flip ? w * 0.34 : w * 0.66;
                var t2 = flip ? w * 0.62 : w * 0.38;
                ctx.beginPath();
                ctx.moveTo(t1, h * 0.28);
                ctx.lineTo(t2, h * 0.5);
                ctx.lineTo(t1, h * 0.72);
                ctx.closePath();
                ctx.fill();
                ctx.fillRect(flip ? w * 0.66 : w * 0.28, h * 0.28, w * 0.07, h * 0.44);
            }
        }
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
        width: root.panelW
        height: column.height + 18
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        color: "transparent"
        title: "nimbus-cc"
        LayerShellQt.Window.layer: LayerShellQt.Window.LayerTop
        LayerShellQt.Window.anchors: LayerShellQt.Window.AnchorTop | LayerShellQt.Window.AnchorRight
        LayerShellQt.Window.exclusionZone: 0
        LayerShellQt.Window.keyboardInteractivity: LayerShellQt.Window.KeyboardInteractivityNone
        LayerShellQt.Window.scope: "nimbus-cc"
        LayerShellQt.Window.activateOnShow: false

        // Sin Rectangle exterior: el panel "es" sus cápsulas.
        Column {
            id: column
            anchors.top: parent.top
            anchors.topMargin: 8
            anchors.right: parent.right
            anchors.rightMargin: 12
            width: root.contentW
            spacing: root.gap

            // ── Fila superior: columna izquierda + módulo grande ────────
            Row {
                width: root.contentW
                height: leftCol.height
                spacing: root.gap

                Column {
                    id: leftCol
                    width: root.cellW
                    spacing: root.gap

                    // Wi-Fi
                    GlassCapsule {
                        width: root.cellW
                        height: root.capsuleH
                        focusRing: wifiArea.activeFocus
                        objectName: "ccTile:Wi-Fi"
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 10
                            spacing: 10
                            Rectangle {
                                width: 34
                                height: 34
                                radius: 17
                                anchors.verticalCenter: parent.verticalCenter
                                color: root.wifiOn ? root.badgeOn : root.badgeOff
                                Glyph {
                                    anchors.centerIn: parent
                                    width: 20
                                    height: 20
                                    kind: "wifi"
                                    stroke: root.wifiOn ? root.accent : root.textMain
                                }
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 44
                                spacing: 1
                                Text {
                                    text: "Wi-Fi"
                                    width: parent.width
                                    elide: Text.ElideRight
                                    font.family: NimbusTokens.fontFamily
                                    font.pixelSize: NimbusTokens.type.t13.size
                                    font.weight: NimbusTokens.type.t13b.weight
                                    color: root.textMain
                                }
                                Text {
                                    text: root.wifiSub
                                    width: parent.width
                                    elide: Text.ElideRight
                                    font.family: NimbusTokens.fontFamily
                                    font.pixelSize: NimbusTokens.type.t11.size
                                    color: root.textSub
                                }
                            }
                        }
                        MouseArea {
                            id: wifiArea
                            anchors.fill: parent
                            hoverEnabled: true
                            activeFocusOnTab: true
                            onClicked: root.flip("wifi")
                            Keys.onReturnPressed: root.flip("wifi")
                        }
                    }

                    // Bluetooth
                    GlassCapsule {
                        width: root.cellW
                        height: root.capsuleH
                        focusRing: btArea.activeFocus
                        objectName: "ccTile:Bluetooth"
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 10
                            spacing: 10
                            Rectangle {
                                width: 34
                                height: 34
                                radius: 17
                                anchors.verticalCenter: parent.verticalCenter
                                color: root.btOn ? root.badgeOn : root.badgeOff
                                Glyph {
                                    anchors.centerIn: parent
                                    width: 20
                                    height: 20
                                    kind: "bluetooth"
                                    stroke: root.btOn ? root.accent : root.textMain
                                }
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 44
                                spacing: 1
                                Text {
                                    text: "Bluetooth"
                                    width: parent.width
                                    elide: Text.ElideRight
                                    font.family: NimbusTokens.fontFamily
                                    font.pixelSize: NimbusTokens.type.t13.size
                                    font.weight: NimbusTokens.type.t13b.weight
                                    color: root.textMain
                                }
                                Text {
                                    text: root.btSub
                                    width: parent.width
                                    elide: Text.ElideRight
                                    font.family: NimbusTokens.fontFamily
                                    font.pixelSize: NimbusTokens.type.t11.size
                                    color: root.textSub
                                }
                            }
                        }
                        MouseArea {
                            id: btArea
                            anchors.fill: parent
                            hoverEnabled: true
                            activeFocusOnTab: true
                            onClicked: root.flip("bt")
                            Keys.onReturnPressed: root.flip("bt")
                        }
                    }

                    // No molestar / AirDrop
                    GlassCapsule {
                        width: root.cellW
                        height: root.capsuleH
                        focusRing: dndArea.activeFocus
                        objectName: "ccTile:No molestar"
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 10
                            spacing: 10
                            Rectangle {
                                width: 34
                                height: 34
                                radius: 17
                                anchors.verticalCenter: parent.verticalCenter
                                color: root.dndOn ? root.badgeOn : root.badgeOff
                                Glyph {
                                    anchors.centerIn: parent
                                    width: 19
                                    height: 19
                                    kind: "moon"
                                    stroke: root.dndOn ? root.accent : root.textMain
                                }
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 44
                                spacing: 1
                                Text {
                                    text: "No molestar"
                                    width: parent.width
                                    elide: Text.ElideRight
                                    font.family: NimbusTokens.fontFamily
                                    font.pixelSize: NimbusTokens.type.t13.size
                                    font.weight: NimbusTokens.type.t13b.weight
                                    color: root.textMain
                                }
                                Text {
                                    text: root.dndSub
                                    width: parent.width
                                    elide: Text.ElideRight
                                    font.family: NimbusTokens.fontFamily
                                    font.pixelSize: NimbusTokens.type.t11.size
                                    color: root.textSub
                                }
                            }
                        }
                        MouseArea {
                            id: dndArea
                            anchors.fill: parent
                            hoverEnabled: true
                            activeFocusOnTab: true
                            onClicked: root.flip("dnd")
                            Keys.onReturnPressed: root.flip("dnd")
                        }
                    }
                }

                // Columna derecha: módulo grande (2 filas) + accesos
                Column {
                    width: root.cellW
                    spacing: root.gap

                    GlassCapsule {
                        width: root.cellW
                        height: 140
                        objectName: "ccMedia"
                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 0
                            Item {
                                width: parent.width
                                height: 70
                                Row {
                                    anchors.fill: parent
                                    spacing: 8
                                    Rectangle {
                                        width: 40
                                        height: 40
                                        radius: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: Qt.rgba(1, 1, 1, 0.12)
                                        objectName: "ccArt"
                                        Image {
                                            anchors.fill: parent
                                            anchors.margins: 2
                                            visible: mpris.artFile !== ""
                                            fillMode: Image.PreserveAspectCrop
                                            source: mpris.artFile !== "" ? "file://" + mpris.artFile : ""
                                        }
                                        Glyph {
                                            anchors.centerIn: parent
                                            width: 22
                                            height: 22
                                            kind: "music"
                                            visible: mpris.artFile === ""
                                            stroke: root.textSub
                                        }
                                    }
                                    Column {
                                        width: parent.width - 48
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1
                                        Text {
                                            text: mpris.hasPlayer ? mpris.title : "Ahora suena"
                                            width: parent.width
                                            elide: Text.ElideRight
                                            font.family: NimbusTokens.fontFamily
                                            font.pixelSize: NimbusTokens.type.t12.size
                                            font.weight: NimbusTokens.type.t13b.weight
                                            color: root.textMain
                                            objectName: "ccMediaTitle"
                                        }
                                        Text {
                                            text: mpris.hasPlayer ? mpris.artist : "Sin reproducción"
                                            width: parent.width
                                            elide: Text.ElideRight
                                            font.family: NimbusTokens.fontFamily
                                            font.pixelSize: NimbusTokens.type.t11.size
                                            color: root.textSub
                                            objectName: "ccMediaArtist"
                                        }
                                        Row {
                                            visible: mpris.hasPlayer
                                            spacing: 2
                                            Repeater {
                                                model: [
                                                    {
                                                        fn: "prev",
                                                        kind: "prev",
                                                        name: "ccPrev"
                                                    },
                                                    {
                                                        fn: "play",
                                                        kind: "play",
                                                        name: "ccPlay"
                                                    },
                                                    {
                                                        fn: "next",
                                                        kind: "next",
                                                        name: "ccNext"
                                                    }
                                                ]
                                                delegate: Rectangle {
                                                    width: 22
                                                    height: 20
                                                    radius: 6
                                                    color: ctrlArea.pressed ? NimbusTokens.pressedFill(NimbusTokens.dark) : ctrlArea.containsMouse ? NimbusTokens.hoverFill(NimbusTokens.dark) : "transparent"
                                                    objectName: modelData.name
                                                    Glyph {
                                                        anchors.centerIn: parent
                                                        width: 14
                                                        height: 14
                                                        kind: modelData.kind === "play" ? (mpris.playing ? "pause" : "play") : modelData.kind
                                                        stroke: root.textMain
                                                    }
                                                    MouseArea {
                                                        id: ctrlArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        activeFocusOnTab: true
                                                        onClicked: {
                                                            if (modelData.fn === "play")
                                                                mpris.playPause();
                                                            else if (modelData.fn === "next")
                                                                mpris.next();
                                                            else
                                                                mpris.previous();
                                                        }
                                                        Keys.onReturnPressed: {
                                                            if (modelData.fn === "play")
                                                                mpris.playPause();
                                                            else if (modelData.fn === "next")
                                                                mpris.next();
                                                            else
                                                                mpris.previous();
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            Rectangle {
                                width: parent.width
                                height: 1
                                color: root.glassBorder
                            }
                            Item {
                                width: parent.width
                                height: 49
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Glyph {
                                        width: 32
                                        height: 18
                                        kind: "battery"
                                        level: root.battLevel
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 0
                                        Text {
                                            text: root.batt === "" || root.batt === "—" ? "—" : root.batt
                                            font.family: NimbusTokens.fontFamily
                                            font.pixelSize: NimbusTokens.type.t17.size
                                            font.weight: NimbusTokens.type.t17.weightEmph
                                            color: root.textMain
                                            objectName: "ccBatt"
                                        }
                                        Text {
                                            text: "Batería"
                                            font.family: NimbusTokens.fontFamily
                                            font.pixelSize: NimbusTokens.type.t11.size
                                            color: root.textSub
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        width: root.cellW
                        height: root.capsuleH
                        spacing: 8

                        // Modo oscuro (botón circular)
                        GlassCapsule {
                            width: 48
                            height: 48
                            cornerRadius: 24
                            anchors.verticalCenter: parent.verticalCenter
                            focusRing: darkArea.activeFocus
                            objectName: "ccDark"
                            Rectangle {
                                anchors.centerIn: parent
                                width: 30
                                height: 30
                                radius: 15
                                color: root.darkOn ? root.badgeOn : root.badgeOff
                                Glyph {
                                    anchors.centerIn: parent
                                    width: 17
                                    height: 17
                                    kind: "moon"
                                    stroke: root.darkOn ? root.accent : root.textMain
                                }
                            }
                            MouseArea {
                                id: darkArea
                                anchors.fill: parent
                                hoverEnabled: true
                                activeFocusOnTab: true
                                onClicked: root.flip("theme")
                                Keys.onReturnPressed: root.flip("theme")
                            }
                        }

                        // Batería (botón circular; pulsa para refrescar)
                        GlassCapsule {
                            width: 48
                            height: 48
                            cornerRadius: 24
                            anchors.verticalCenter: parent.verticalCenter
                            focusRing: battArea.activeFocus
                            objectName: "ccBatteryBtn"
                            Column {
                                anchors.centerIn: parent
                                spacing: 1
                                Glyph {
                                    width: 24
                                    height: 13
                                    kind: "battery"
                                    level: root.battLevel
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Text {
                                    text: root.batt === "" || root.batt === "—" ? "—" : root.batt
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    font.family: NimbusTokens.fontFamily
                                    font.pixelSize: 9
                                    color: root.textSub
                                }
                            }
                            MouseArea {
                                id: battArea
                                anchors.fill: parent
                                hoverEnabled: true
                                activeFocusOnTab: true
                                onClicked: root.refresh()
                                Keys.onReturnPressed: root.refresh()
                            }
                        }

                        // Enfoque / No molestar
                        GlassCapsule {
                            width: root.cellW - 48 * 2 - 16
                            height: root.capsuleH
                            focusRing: focusArea.activeFocus
                            objectName: "ccFocus"
                            Column {
                                anchors.centerIn: parent
                                spacing: 3
                                Rectangle {
                                    width: 26
                                    height: 26
                                    radius: 13
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: root.dndOn ? root.badgeOn : root.badgeOff
                                    Glyph {
                                        anchors.centerIn: parent
                                        width: 15
                                        height: 15
                                        kind: "moon"
                                        stroke: root.dndOn ? root.accent : root.textMain
                                    }
                                }
                                Text {
                                    text: "Enfoque"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    font.family: NimbusTokens.fontFamily
                                    font.pixelSize: 10
                                    color: root.textMain
                                }
                            }
                            MouseArea {
                                id: focusArea
                                anchors.fill: parent
                                hoverEnabled: true
                                activeFocusOnTab: true
                                onClicked: root.flip("dnd")
                                Keys.onReturnPressed: root.flip("dnd")
                            }
                        }
                    }
                }
            }

            // ── Display (ancho completo) ────────────────────────────────
            GlassCapsule {
                width: root.contentW
                height: 96
                cornerRadius: 26
                focusRing: briSlider.activeFocus
                objectName: "ccTile:Display"
                Column {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.topMargin: 9
                    anchors.bottomMargin: 8
                    spacing: 2
                    Text {
                        text: "Pantalla"
                        font.family: NimbusTokens.fontFamily
                        font.pixelSize: NimbusTokens.type.t12.size
                        font.weight: NimbusTokens.type.t13b.weight
                        color: root.textMain
                    }
                    Row {
                        id: briRow
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10
                        Glyph {
                            width: 18
                            height: 18
                            kind: "sun"
                            anchors.verticalCenter: parent.verticalCenter
                            stroke: root.textSub
                        }
                        Slider {
                            id: briSlider
                            width: Math.max(0, briRow.width - 36 - 28 - 20)
                            height: 28
                            anchors.verticalCenter: parent.verticalCenter
                            from: 0
                            to: 1
                            value: root.bri < 0 ? 0.5 : root.bri
                            enabled: !root.demo && root.bri >= 0
                            opacity: enabled ? 1 : 0.62
                            objectName: "ccBri"
                            onMoved: runner.run("brightnessctl set " + Math.round(value * 100) + "%")
                            background: Rectangle {
                                x: 0
                                y: (parent.height - height) / 2
                                width: parent.width
                                height: 6
                                radius: 3
                                color: Qt.rgba(1, 1, 1, 0.2)
                                Rectangle {
                                    width: parent.width * briSlider.visualPosition
                                    height: parent.height
                                    radius: 3
                                    color: root.textMain
                                }
                            }
                            handle: Rectangle {
                                x: briSlider.visualPosition * (briSlider.width - width)
                                y: (briSlider.height - height) / 2
                                width: 20
                                height: 20
                                radius: 10
                                color: root.textMain
                            }
                        }
                        Glyph {
                            width: 26
                            height: 26
                            kind: "sun"
                            anchors.verticalCenter: parent.verticalCenter
                            stroke: root.textMain
                        }
                    }
                }
            }

            // ── Sonido (ancho completo) ─────────────────────────────────
            GlassCapsule {
                width: root.contentW
                height: 96
                cornerRadius: 26
                focusRing: volSlider.activeFocus
                objectName: "ccTile:Sonido"
                Column {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.topMargin: 9
                    anchors.bottomMargin: 8
                    spacing: 2
                    Text {
                        text: "Sonido"
                        font.family: NimbusTokens.fontFamily
                        font.pixelSize: NimbusTokens.type.t12.size
                        font.weight: NimbusTokens.type.t13b.weight
                        color: root.textMain
                    }
                    Row {
                        id: volRow
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10
                        Glyph {
                            width: 18
                            height: 18
                            kind: "speaker"
                            anchors.verticalCenter: parent.verticalCenter
                            stroke: root.textSub
                        }
                        Slider {
                            id: volSlider
                            width: Math.max(0, volRow.width - 36 - 28 - 20)
                            height: 28
                            anchors.verticalCenter: parent.verticalCenter
                            from: 0
                            to: 1
                            value: root.vol < 0 ? 0.5 : root.vol
                            enabled: !root.demo && root.vol >= 0
                            opacity: enabled ? 1 : 0.62
                            objectName: "ccVol"
                            onMoved: runner.run("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + value.toFixed(2))
                            background: Rectangle {
                                x: 0
                                y: (parent.height - height) / 2
                                width: parent.width
                                height: 6
                                radius: 3
                                color: Qt.rgba(1, 1, 1, 0.2)
                                Rectangle {
                                    width: parent.width * volSlider.visualPosition
                                    height: parent.height
                                    radius: 3
                                    color: root.textMain
                                }
                            }
                            handle: Rectangle {
                                x: volSlider.visualPosition * (volSlider.width - width)
                                y: (volSlider.height - height) / 2
                                width: 20
                                height: 20
                                radius: 10
                                color: root.textMain
                            }
                        }
                        Glyph {
                            width: 26
                            height: 26
                            kind: "speaker"
                            anchors.verticalCenter: parent.verticalCenter
                            stroke: root.textMain
                        }
                    }
                }
            }
        }
    }
}
