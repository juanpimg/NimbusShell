// OSD.qml — burbuja glass volumen/brillo bajo la barra (F3-T10, contrato §3).
// OSD brillo/volumen se expande in-situ [HIG]: burbuja centro-derecha bajo
// la barra (y=28, patrón CC/Calendar), icono + slider + valor. Canales
// reales (solo lectura salvo mover el slider): volumen `wpctl get-volume`
// (fallback `pactl`); brillo `brightnessctl -m` (fallback
// /sys/class/backlight). Auto-oculta 1.5s; sin foco
// (KeyboardInteractivityNone, activateOnShow false); clic fuera + Esc
// cierran. show(kind,value) lo invocan DBus org.nimbus.OSD (/OSD) vía el
// puente osdBridge, --demo-osd y el propio refresh().
import QtQuick
import QtQuick.Controls
import org.kde.layershell as LayerShellQt

Item {
    id: root
    property bool opened: false
    property bool demo: false
    property string kind: "volume" // "volume" | "brightness"
    property real value: -1 // 0..1; -1 = sin canal real ni valor demo
    property bool muted: false
    function show(k, v) {
        if (k === "volume" || k === "brightness")
            kind = k;
        if (v !== undefined && v >= 0)
            value = Math.min(1, Math.max(0, v));
        opened = true;
        hideTimer.restart();
        refresh();
    }
    function hide() {
        opened = false;
    }
    function refresh() {
        // Solo lectura (seguro en demo/nested); el slider sí ejecuta en vivo.
        runner.query("wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -m1 -o '[0-9]*%' || echo —", "osdVol");
        // brightnessctl ausente emite "" (no fallo: cut/tr exito); por eso
        // el fallback sysfs va en variable y no en `||`.
        runner.query("b=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d ' %'); if [ -n \"$b\" ]; then echo \"$b\"; else d=$(ls -d /sys/class/backlight/* 2>/dev/null | head -1); if [ -n \"$d\" ]; then echo $(($(cat $d/brightness) * 100 / $(cat $d/max_brightness))); else echo —; fi; fi", "osdBri");
    }
    function setFromSlider(v) {
        value = Math.min(1, Math.max(0, v));
        hideTimer.restart();
        if (demo) {
            console.log("osd: slider " + kind + " " + value.toFixed(2) + " (demo, no ejecutado)");
            return;
        }
        if (kind === "volume")
            runner.run("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + value.toFixed(2));
        else
            runner.run("brightnessctl set " + Math.round(value * 100) + "%");
    }
    function glyph() {
        if (kind === "brightness")
            return "B";
        return muted ? "X" : "V";
    }
    function label() {
        if (value < 0)
            return kind === "volume" ? "Volumen —" : "Brillo —";
        return (kind === "volume" ? "Volumen " : "Brillo ") + Math.round(value * 100) + "%";
    }
    Connections {
        target: runner
        function onOutputReady(tag, out) {
            if (tag === "osdVol" && root.kind === "volume") {
                if (out === "" || out === "—")
                    return;
                root.muted = out.indexOf("MUTED") >= 0;
                var m = out.match(/([0-9]+(?:\.[0-9]+)?)/);
                if (m) {
                    var n = parseFloat(m[1]);
                    root.value = out.indexOf("%") >= 0 ? Math.min(1, n / 100) : Math.min(1, n);
                }
            } else if (tag === "osdBri" && root.kind === "brightness") {
                if (out === "" || out === "—")
                    return;
                var b = parseFloat(out);
                if (!isNaN(b))
                    root.value = Math.min(1, b / 100);
            }
        }
    }
    Connections {
        target: osdBridge
        function onOsdShow(k, v) {
            root.show(k, v);
        }
    }
    Timer {
        id: hideTimer
        interval: 1500
        repeat: false
        onTriggered: root.hide()
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
        title: "nimbus-osd-scrim"
        LayerShellQt.Window.layer: LayerShellQt.Window.LayerTop
        LayerShellQt.Window.exclusionZone: 0
        LayerShellQt.Window.keyboardInteractivity: LayerShellQt.Window.KeyboardInteractivityOnDemand
        LayerShellQt.Window.scope: "nimbus-osd-scrim"
        LayerShellQt.Window.activateOnShow: false
        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()
        }
        Shortcut {
            sequence: "Escape"
            enabled: root.opened
            onActivated: root.hide()
        }
    }
    Window {
        id: popup
        visible: root.opened
        width: 280
        height: 56
        x: Math.round(Screen.width * 0.62)
        y: 28
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        color: "transparent"
        title: "nimbus-osd"
        LayerShellQt.Window.layer: LayerShellQt.Window.LayerTop
        LayerShellQt.Window.anchors: LayerShellQt.Window.AnchorTop
        LayerShellQt.Window.exclusionZone: 0
        LayerShellQt.Window.keyboardInteractivity: LayerShellQt.Window.KeyboardInteractivityNone
        LayerShellQt.Window.scope: "nimbus-osd"
        LayerShellQt.Window.activateOnShow: false
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: NimbusTokens.popupBg(NimbusTokens.dark)
            border.color: NimbusTokens.popupBorder(NimbusTokens.dark)
            border.width: 1
            objectName: "osdPopup"
            Row {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.glyph()
                    font.family: NimbusTokens.fontFamily
                    font.pixelSize: 16
                    font.weight: 700
                    color: NimbusTokens.accentColor(NimbusTokens.dark)
                    objectName: "osdIcon"
                }
                Slider {
                    id: slider
                    anchors.verticalCenter: parent.verticalCenter
                    width: 140
                    from: 0
                    to: 1
                    value: root.value < 0 ? 0 : root.value
                    enabled: root.value >= 0
                    // F11-T03: disabled tokenizado, foco 2px [HIG §2.5].
                    opacity: enabled ? 1.0 : NimbusTokens.states.disabledOpacity[0]
                    objectName: "osdSlider"
                    onMoved: root.setFromSlider(value)
                    background: Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.availableWidth
                        height: 4
                        radius: 2
                        color: NimbusTokens.hoverFill(NimbusTokens.dark)
                        border.color: NimbusTokens.accentColor(NimbusTokens.dark)
                        border.width: slider.activeFocus ? NimbusTokens.states.focusRingPx : 0
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.label()
                    font.family: NimbusTokens.fontFamily
                    font.pixelSize: NimbusTokens.type.t12.size
                    color: NimbusTokens.colors(NimbusTokens.dark).label
                    objectName: "osdValue"
                }
            }
        }
    }
}
