import QtQuick

// NimbusLockClock — reloj grande estilo login macOS + fecha (F10-T04).
// Solo visual: hora tabular (mono), fecha t13. Sin activos Apple.
Item {
    id: clockRoot

    property string fontFamily: "Inter"
    property string monoFamily: "JetBrains Mono"
    property color textColor: "white"
    property color subColor: "#EBEBF5"
    property bool use24h: true

    function tick() {
        var d = new Date();
        var h = d.getHours();
        var m = d.getMinutes();
        if (!use24h) {
            h = h % 12;
            if (h === 0)
                h = 12;
        }
        timeText.text = h + ":" + (m < 10 ? "0" + m : m);
        var days = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"];
        var months = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"];
        dateText.text = days[d.getDay()] + ", " + d.getDate() + " de " + months[d.getMonth()];
    }

    implicitWidth: 400
    implicitHeight: timeText.implicitHeight + dateText.implicitHeight + 8
    Component.onCompleted: clockRoot.tick()

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8

        Text {
            id: timeText

            anchors.horizontalCenter: parent.horizontalCenter
            font.family: clockRoot.monoFamily
            font.pixelSize: 96
            font.weight: 600
            color: clockRoot.textColor
            Accessible.name: "Hora actual"
        }

        Text {
            id: dateText

            anchors.horizontalCenter: parent.horizontalCenter
            font.family: clockRoot.fontFamily
            font.pixelSize: 17
            font.weight: 400
            color: clockRoot.subColor
            opacity: 0.85
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: clockRoot.tick()
    }
}
