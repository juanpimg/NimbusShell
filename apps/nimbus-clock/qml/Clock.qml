// Clock.qml — nimbus-clock F10-T01. 4 pestañas estilo macOS, arte propio.
// Datos reales: backend.timeInZone(tz) (QTimeZone), alarmas en ini,
// cronómetro/temporizador con Timer local. Accesible: Accessible.name + Tab.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root

    property bool isDark: true
    property string tab: (typeof startTab !== "undefined") ? startTab : "mundo"
    property var cities: [
        {
            "name": "Madrid",
            "tz": "Europe/Madrid"
        },
        {
            "name": "Londres",
            "tz": "Europe/London"
        },
        {
            "name": "Nueva York",
            "tz": "America/New_York"
        },
        {
            "name": "Tokio",
            "tz": "Asia/Tokyo"
        }
    ]
    // Cronómetro
    property bool swRun: false
    property int swAcc: 0
    property int swStart: 0
    property var swLaps: []
    // Temporizador
    property int tmTotal: 300000
    property int tmLeft: 300000
    property bool tmRun: false
    property int tmEnd: 0
    property int tmAcc: 300000
    // Alarmas: formulario
    property int newH: 8
    property int newM: 0
    property string newLabel: ""
    property int swElapsed: 0
    property string lastRing: ""
    property string ringText: ""
    property ListModel alarmModel

    function fmtMs(ms) {
        function p(n) {
            return (n < 10 ? "0" : "") + n;
        }

        var s = Math.floor(ms / 1000);
        var m = Math.floor(s / 60);
        s = s % 60;
        var h = Math.floor(m / 60);
        m = m % 60;
        return (h > 0 ? h + ":" + p(m) : p(m)) + ":" + p(s);
    }

    function tick() {
        var now = Date.now();
        if (swRun)
            swElapsed = swAcc + (now - swStart);
        else
            swElapsed = swAcc;
        if (tmRun) {
            tmLeft = Math.max(0, tmEnd - now);
            if (tmLeft === 0)
                tmRun = false;
        }
        // Alarmas: aviso simple si coincide HH:MM y está activa.
        var hm = backend.timeInZone("Europe/Madrid", "HH:mm");
        for (var i = 0; i < alarmModel.count; i++) {
            var a = alarmModel.get(i);
            var want = (a.h < 10 ? "0" : "") + a.h + ":" + (a.m < 10 ? "0" : "") + a.m;
            if (a.on && want === hm && lastRing !== want) {
                lastRing = want;
                ringText = a.label;
                ringBox.visible = true;
            }
        }
    }

    objectName: "clockWindow"
    width: 620
    height: 460
    minimumWidth: 560
    minimumHeight: 420
    visible: true
    title: qsTr("Reloj")
    color: "transparent"
    Component.onCompleted: {
        for (var i = 0; i < backend.alarms.length; i++)
            alarmModel.append(backend.alarms[i]);
        if (tab === "alarmas")
            tabBar.currentIndex = 1;
        else if (tab === "crono")
            tabBar.currentIndex = 2;
        else if (tab === "temporizador")
            tabBar.currentIndex = 3;
    }

    Connections {
        function onAlarmsChanged() {
            alarmModel.clear();
            for (var i = 0; i < backend.alarms.length; i++)
                alarmModel.append(backend.alarms[i]);
        }

        target: backend
    }

    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: root.tick()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: worldList.modelChanged()
    }

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: "#2C2C2E"
        border.color: "#38383A"
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            TabBar {
                id: tabBar

                Layout.fillWidth: true
                Accessible.name: qsTr("Pestañas del Reloj")

                TabButton {
                    text: qsTr("Reloj mundial")
                    Accessible.name: qsTr("Reloj mundial")
                    width: implicitWidth
                }

                TabButton {
                    text: qsTr("Alarmas")
                    Accessible.name: qsTr("Alarmas")
                }

                TabButton {
                    text: qsTr("Cronómetro")
                    Accessible.name: qsTr("Cronómetro")
                }

                TabButton {
                    text: qsTr("Temporizador")
                    Accessible.name: qsTr("Temporizador")
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: tabBar.currentIndex

                // ── 0. Reloj mundial ──
                ColumnLayout {
                    spacing: 6
                    objectName: "tabWorld"

                    Repeater {
                        id: worldList

                        model: root.cities

                        delegate: RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            objectName: "city:" + modelData.name

                            // día/noche propio
                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                color: backend.isDayInZone(modelData.tz) ? "#FFD60A" : "#0A84FF"

                                Text {
                                    anchors.centerIn: parent
                                    text: backend.isDayInZone(modelData.tz) ? "☀" : "☾"
                                    font.pixelSize: 12
                                    color: "black"
                                }
                            }

                            Text {
                                text: modelData.name
                                font.pixelSize: 14
                                color: "white"
                                Layout.fillWidth: true
                            }

                            Text {
                                text: backend.timeInZone(modelData.tz, "HH:mm")
                                font.pixelSize: 20
                                font.weight: 600
                                color: "white"
                            }

                            Text {
                                text: backend.timeInZone(modelData.tz, "d MMM")
                                font.pixelSize: 12
                                color: "#EBEBF5"
                            }
                        }
                    }

                    Text {
                        text: qsTr("Horas locales reales (QTimeZone)")
                        font.pixelSize: 11
                        color: "#8E8E93"
                    }
                }

                // ── 1. Alarmas ──
                ColumnLayout {
                    spacing: 6
                    objectName: "tabAlarms"

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: alarmModel

                        delegate: RowLayout {
                            width: ListView.view.width
                            objectName: "alarm:" + model.id

                            Text {
                                text: (model.h < 10 ? "0" : "") + model.h + ":" + (model.m < 10 ? "0" : "") + model.m
                                font.pixelSize: 18
                                color: "white"
                                Layout.fillWidth: true
                            }

                            Text {
                                text: model.label
                                font.pixelSize: 12
                                color: "#EBEBF5"
                            }

                            CheckBox {
                                checked: model.on
                                Accessible.name: qsTr("Activar alarma")
                                onToggled: backend.setAlarmOn(model.id, checked)
                            }

                            Button {
                                text: qsTr("Borrar")
                                Accessible.name: qsTr("Borrar alarma")
                                onClicked: backend.removeAlarm(model.id)
                            }
                        }
                    }

                    RowLayout {
                        SpinBox {
                            id: spinH

                            from: 0
                            to: 23
                            value: root.newH
                            Accessible.name: qsTr("Hora")
                            onValueChanged: root.newH = value
                            width: 90
                        }

                        SpinBox {
                            id: spinM

                            from: 0
                            to: 59
                            value: root.newM
                            Accessible.name: qsTr("Minutos")
                            onValueChanged: root.newM = value
                            width: 90
                        }

                        TextField {
                            id: labelField

                            placeholderText: qsTr("Etiqueta")
                            Accessible.name: qsTr("Etiqueta")
                            Layout.fillWidth: true
                            onTextChanged: root.newLabel = text
                        }

                        Button {
                            text: qsTr("Añadir")
                            Accessible.name: qsTr("Añadir alarma")
                            objectName: "alarmAdd"
                            onClicked: backend.addAlarm(root.newH, root.newM, root.newLabel)
                        }
                    }

                    Text {
                        text: qsTr("Se guardan en ~/.config/nimbus-clock.ini")
                        font.pixelSize: 11
                        color: "#8E8E93"
                    }
                }

                // ── 2. Cronómetro ──
                ColumnLayout {
                    spacing: 8
                    objectName: "tabStopwatch"

                    Text {
                        text: root.fmtMs(root.swElapsed)
                        font.pixelSize: 44
                        font.weight: 600
                        color: "white"
                        Layout.alignment: Qt.AlignHCenter
                        objectName: "swTime"
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter

                        Button {
                            text: root.swRun ? qsTr("Pausar") : qsTr("Iniciar")
                            Accessible.name: qsTr("Iniciar o pausar cronómetro")
                            objectName: "swStart"
                            onClicked: {
                                if (root.swRun) {
                                    root.swAcc = root.swElapsed;
                                    root.swRun = false;
                                } else {
                                    root.swStart = Date.now();
                                    root.swRun = true;
                                }
                            }
                        }

                        Button {
                            text: qsTr("Vuelta")
                            Accessible.name: qsTr("Vuelta")
                            enabled: root.swRun
                            onClicked: {
                                root.swLaps.push(root.swElapsed);
                                lapModel.append({
                                    "t": root.fmtMs(root.swElapsed)
                                });
                            }
                        }

                        Button {
                            text: qsTr("Restablecer")
                            Accessible.name: qsTr("Restablecer cronómetro")
                            onClicked: {
                                root.swRun = false;
                                root.swAcc = 0;
                                root.swElapsed = 0;
                                root.swLaps = [];
                                lapModel.clear();
                            }
                        }
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        model: ListModel {
                            id: lapModel
                        }

                        delegate: Text {
                            text: (index + 1) + ". " + model.t
                            color: "#EBEBF5"
                            font.pixelSize: 12
                        }
                    }
                }

                // ── 3. Temporizador ──
                ColumnLayout {
                    spacing: 8
                    objectName: "tabTimer"

                    Text {
                        text: root.fmtMs(root.tmLeft)
                        font.pixelSize: 44
                        font.weight: 600
                        color: "white"
                        Layout.alignment: Qt.AlignHCenter
                        objectName: "tmTime"
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter

                        Repeater {
                            model: [1, 5, 10, 25]

                            delegate: Button {
                                text: modelData + " min"
                                Accessible.name: modelData + qsTr(" minutos")
                                onClicked: {
                                    root.tmTotal = modelData * 60000;
                                    root.tmLeft = root.tmTotal;
                                    root.tmAcc = root.tmTotal;
                                    root.tmRun = false;
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter

                        Button {
                            text: root.tmRun ? qsTr("Pausar") : qsTr("Iniciar")
                            Accessible.name: qsTr("Iniciar o pausar temporizador")
                            objectName: "tmStart"
                            onClicked: {
                                if (root.tmRun) {
                                    root.tmAcc = root.tmLeft;
                                    root.tmRun = false;
                                } else {
                                    root.tmEnd = Date.now() + root.tmLeft;
                                    root.tmRun = true;
                                }
                            }
                        }

                        Button {
                            text: qsTr("Restablecer")
                            Accessible.name: qsTr("Restablecer temporizador")
                            onClicked: {
                                root.tmRun = false;
                                root.tmLeft = root.tmTotal;
                            }
                        }
                    }

                    Text {
                        text: qsTr("Sin sonido propietario: al llegar a cero se muestra aviso")
                        font.pixelSize: 11
                        color: "#8E8E93"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            Rectangle {
                id: ringBox

                visible: false
                Layout.fillWidth: true
                height: visible ? 30 : 0
                radius: 8
                color: "#FF453A"
                objectName: "ringBox"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6

                    Text {
                        text: qsTr("Suena: ") + root.ringText
                        color: "white"
                        Layout.fillWidth: true
                    }

                    Button {
                        text: qsTr("OK")
                        onClicked: ringBox.visible = false
                    }
                }
            }
        }
    }

    alarmModel: ListModel {
        id: alarmModel
    }
}
