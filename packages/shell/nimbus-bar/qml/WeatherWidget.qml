// WeatherWidget.qml — F10-T01 Tiempo en Calendar.qml (no en la barra de 24px).
// Ciudad, temp actual, condición, min/max y 3 días. Iconos dibujados propios
// (Canvas: sol/nube/lluvia/nieve/tormenta). Offline honesto: «—» si no hay
// caché ni red.
import QtQuick

Column {
    id: root
    width: parent ? parent.width : 260
    spacing: 4
    objectName: "calWeather"
    property var model: (typeof weather !== "undefined") ? weather : null
    function glyphFor(code) {
        if (code < 0)
            return "—";
        if (code === 0)
            return "sol";
        if (code <= 3)
            return "nube";
        if (code <= 48)
            return "niebla";
        if (code <= 67 || (code >= 80 && code <= 82))
            return "lluvia";
        if (code <= 77)
            return "nieve";
        return "tormenta";
    }
    Rectangle {
        width: parent.width
        height: 1
        color: NimbusTokens.popupBorder(NimbusTokens.dark)
    }
    Row {
        width: parent.width
        spacing: 10
        Canvas {
            id: glyph
            width: 36
            height: 36
            property string kind: root.glyphFor(root.model ? root.model.condCode : -1)
            onKindChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.fillStyle = "#FFD60A";
                ctx.strokeStyle = "#8E8E93";
                ctx.lineWidth = 1.5;
                if (kind === "sol") {
                    ctx.beginPath();
                    ctx.arc(18, 18, 9, 0, 2 * Math.PI);
                    ctx.fill();
                } else if (kind === "nube" || kind === "niebla") {
                    ctx.fillStyle = "#AEAEB2";
                    ctx.beginPath();
                    ctx.arc(13, 22, 7, 0, 2 * Math.PI);
                    ctx.fill();
                    ctx.beginPath();
                    ctx.arc(22, 19, 9, 0, 2 * Math.PI);
                    ctx.fill();
                    ctx.beginPath();
                    ctx.arc(28, 23, 6, 0, 2 * Math.PI);
                    ctx.fill();
                } else if (kind === "lluvia") {
                    ctx.fillStyle = "#AEAEB2";
                    ctx.beginPath();
                    ctx.arc(18, 14, 9, 0, 2 * Math.PI);
                    ctx.fill();
                    ctx.strokeStyle = "#0A84FF";
                    for (var i = 0; i < 3; i++) {
                        ctx.beginPath();
                        ctx.moveTo(10 + i * 8, 24);
                        ctx.lineTo(8 + i * 8, 32);
                        ctx.stroke();
                    }
                } else if (kind === "nieve") {
                    ctx.fillStyle = "#FFFFFF";
                    ctx.beginPath();
                    ctx.arc(18, 14, 9, 0, 2 * Math.PI);
                    ctx.fill();
                    ctx.fillStyle = "#0A84FF";
                    for (var j = 0; j < 3; j++) {
                        ctx.beginPath();
                        ctx.arc(11 + j * 7, 28, 2, 0, 2 * Math.PI);
                        ctx.fill();
                    }
                } else if (kind === "tormenta") {
                    ctx.fillStyle = "#636366";
                    ctx.beginPath();
                    ctx.arc(18, 13, 9, 0, 2 * Math.PI);
                    ctx.fill();
                    ctx.fillStyle = "#FFD60A";
                    ctx.beginPath();
                    ctx.moveTo(20, 20);
                    ctx.lineTo(14, 30);
                    ctx.lineTo(19, 30);
                    ctx.lineTo(15, 36);
                    ctx.lineTo(23, 27);
                    ctx.lineTo(18, 27);
                    ctx.closePath();
                    ctx.fill();
                } else {
                    ctx.fillStyle = "#8E8E93";
                    ctx.font = "16px sans-serif";
                    ctx.fillText("—", 13, 24);
                }
            }
        }
        Column {
            spacing: 1
            Text {
                text: (root.model ? root.model.city : "—") + " · " + (root.model ? root.model.temp : "—")
                font.pixelSize: 15
                font.weight: 700
                color: NimbusTokens.colors(NimbusTokens.dark).label
                objectName: "wxHead"
            }
            Text {
                text: (root.model ? root.model.cond : "—") + " · " + (root.model ? root.model.minMax : "—") + ((root.model && root.model.stale) ? qsTr(" (caché)") : "")
                font.pixelSize: 11
                color: NimbusTokens.subText(NimbusTokens.dark)
                objectName: "wxSub"
            }
        }
    }
    Row {
        width: parent.width
        spacing: 6
        Repeater {
            model: root.model ? root.model.days : []
            delegate: Column {
                width: (root.width - 12) / 3
                spacing: 1
                Text {
                    text: modelData.d
                    font.pixelSize: 10
                    color: NimbusTokens.faintText(NimbusTokens.dark)
                }
                Text {
                    text: modelData.mx + " " + modelData.mn
                    font.pixelSize: 11
                    color: NimbusTokens.colors(NimbusTokens.dark).label
                }
            }
        }
    }
}
