// WeatherWidget.qml — F10-T01 Tiempo en Calendar.qml (no en la barra de 24px).
// Pie compacto del popover: ciudad, temp actual, condición, min/max y 3 días.
// Iconos dibujados propios (Canvas: sol/nube/lluvia/nieve/tormenta). Offline
// honesto: «—» si no hay caché ni red.
import QtQuick

Column {
    id: root

    width: parent ? parent.width : 260
    spacing: 3
    objectName: "calWeather"
    property var model: (typeof weather !== "undefined") ? weather : null
    // El Canvas dibuja en un lienzo lógico de 36 px y se escala al tamaño
    // compacto del pie (28 px) sin duplicar coordenadas.
    readonly property real canvasSize: 36

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
        height: 28
        spacing: 8

        Canvas {
            id: glyph

            width: 28
            height: 28
            property string kind: root.glyphFor(root.model ? root.model.condCode : -1)
            onKindChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.save();
                ctx.clearRect(0, 0, width, height);
                ctx.scale(width / root.canvasSize, height / root.canvasSize);
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
                ctx.restore();
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                text: (root.model ? root.model.city : "—") + " · " + (root.model ? root.model.temp : "—")
                font.family: NimbusTokens.fontFamily
                font.pixelSize: NimbusTokens.type.t13.size
                font.weight: NimbusTokens.type.t15.weightEmph
                color: NimbusTokens.colors(NimbusTokens.dark).label
                objectName: "wxHead"
            }
            Text {
                text: (root.model ? root.model.cond : "—") + " · " + (root.model ? root.model.minMax : "—") + ((root.model && root.model.stale) ? qsTr(" (caché)") : "")
                font.family: NimbusTokens.fontFamily
                font.pixelSize: NimbusTokens.type.t11.size
                color: NimbusTokens.subText(NimbusTokens.dark)
                objectName: "wxSub"
            }
        }
    }
    Row {
        width: parent.width
        spacing: 8

        Repeater {
            model: root.model ? root.model.days : []

            delegate: Column {
                width: (root.width - 16) / 3
                spacing: 0

                Text {
                    text: modelData.d
                    font.family: NimbusTokens.fontFamily
                    font.pixelSize: NimbusTokens.type.t11.size
                    color: NimbusTokens.faintText(NimbusTokens.dark)
                }
                Text {
                    text: modelData.mx + " " + modelData.mn
                    font.family: NimbusTokens.fontFamily
                    font.pixelSize: NimbusTokens.type.t11.size
                    color: NimbusTokens.colors(NimbusTokens.dark).label
                }
            }
        }
    }
}
