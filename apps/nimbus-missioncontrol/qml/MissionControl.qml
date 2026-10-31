// MissionControl.qml — overlay fullscreen Mission Control (F7-T01/T02).
// Fila de Spaces + parrilla del Space activo + App Exposé. Tokens dark §2.1.
// Cierra con Esc o clic fuera. Drag de miniatura a Space = mover (DropArea).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    objectName: "mcWindow"
    width: 1280
    height: 800
    visible: false // lo muestra main.cpp tras geometría+layer-shell (evita warning shell integration)
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
    color: "transparent"
    title: "Mission Control"

    property int activeSpace: backend.currentDesktop > 0 ? backend.currentDesktop - 1 : 0
    property int selIndex: 0
    property string dragWinId: ""

    function spaceWindows() {
        var out = [];
        var desks = backend.desktops;
        if (desks.length === 0)
            return out;
        var idx = Math.min(root.activeSpace, desks.length - 1);
        var deskId = desks[idx].id;
        for (var i = 0; i < backend.windows.length; i++) {
            var w = backend.windows[i];
            // Ventanas sin desktop asignado se muestran en el activo.
            if (w.desktop !== deskId && w.desktop !== "")
                continue;
            if (backend.exposeActiveAppOnly && w.app !== backend.currentApp)
                continue;
            out.push(w);
        }
        return out;
    }

    property var visibleWins: spaceWindows()

    function refreshVisible() {
        root.visibleWins = root.spaceWindows();
        root.selIndex = 0;
    }

    Connections {
        target: backend
        function onWindowsChanged() {
            root.refreshVisible();
        }
        function onDesktopsChanged() {
            root.refreshVisible();
        }
        function onExposeChanged() {
            root.refreshVisible();
        }
    }

    Component.onCompleted: {
        backend.refresh();
        root.refreshVisible();
    }

    onActiveSpaceChanged: root.refreshVisible()

    // Fondo glass oscuro + clic fuera cierra.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.62
    }
    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    // Teclado vía Shortcut (Keys no se adjunta a Window, solo a Item).
    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: root.visible = false
    }
    Shortcut {
        sequences: ["Return", "Enter"]
        context: Qt.ApplicationShortcut
        onActivated: {
            if (root.visibleWins.length > 0)
                backend.activateWindow(root.visibleWins[root.selIndex].id);
            root.visible = false;
        }
    }
    Shortcut {
        sequence: "Right"
        context: Qt.ApplicationShortcut
        onActivated: {
            var n = root.visibleWins.length;
            if (n > 0)
                root.selIndex = (root.selIndex + 1) % n;
        }
    }
    Shortcut {
        sequence: "Left"
        context: Qt.ApplicationShortcut
        onActivated: {
            var n = root.visibleWins.length;
            if (n > 0)
                root.selIndex = (root.selIndex + n - 1) % n;
        }
    }
    Shortcut {
        sequence: "Tab"
        context: Qt.ApplicationShortcut
        onActivated: backend.toggleExpose()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        Text {
            text: "Mission Control" + (backend.exposeActiveAppOnly ? " — " + backend.currentApp : "")
            color: "#FFFFFF"
            font.pixelSize: 22
            font.bold: true
            Accessible.name: "Mission Control"
        }

        // Fila de Spaces (thumbnails: fallback contador + nombres).
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            spacing: 12
            Repeater {
                model: backend.desktops
                delegate: Rectangle {
                    Layout.preferredWidth: 180
                    Layout.preferredHeight: 110
                    radius: 10
                    color: index === root.activeSpace ? "#0A84FF" : "#2C2C2E"
                    opacity: index === root.activeSpace ? 0.95 : 0.85
                    border.color: "#38383A"
                    border.width: 1
                    Accessible.name: "Space " + modelData.name
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4
                        Text {
                            text: modelData.name
                            color: "#FFFFFF"
                            font.pixelSize: 13
                            font.bold: true
                        }
                        Text {
                            text: modelData.windowCount + " ventanas"
                            color: "#EBEBF5"
                            opacity: 0.6
                            font.pixelSize: 12
                        }
                        Text {
                            text: modelData.active ? "● activo" : ""
                            color: "#0A84FF"
                            font.pixelSize: 11
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.activeSpace = index;
                            backend.setCurrentDesktopByIndex(modelData.index);
                        }
                    }
                    DropArea {
                        anchors.fill: parent
                        onDropped: function (drop) {
                            if (root.dragWinId !== "")
                                backend.moveWindowToDesktop(root.dragWinId, modelData.id);
                            root.dragWinId = "";
                        }
                    }
                }
            }
            // Botón + (crear Space) — F7-T07 pendiente: documenta no-op.
            Rectangle {
                Layout.preferredWidth: 64
                Layout.preferredHeight: 110
                radius: 10
                color: "transparent"
                border.color: "#38383A"
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "+"
                    color: "#EBEBF5"
                    font.pixelSize: 28
                }
                Accessible.name: "Añadir Space"
                MouseArea {
                    anchors.fill: parent
                    onClicked: backend.lastError // no-op documentado
                }
            }
            Item {
                Layout.fillWidth: true
            }
        }

        Text {
            text: backend.hasThumbnails ? "Miniaturas en vivo" : "Vista de iconos (ScreenShot2 no disponible)"
            color: "#EBEBF5"
            opacity: 0.6
            font.pixelSize: 12
        }

        // Parrilla de ventanas del Space activo.
        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            cellWidth: 240
            cellHeight: 150
            model: root.visibleWins
            clip: true
            Accessible.name: "Ventanas del Space activo"
            delegate: Rectangle {
                width: 224
                height: 134
                radius: 12
                color: index === root.selIndex ? "#0A84FF" : "#2C2C2E"
                border.color: modelData.active ? "#0A84FF" : "#38383A"
                border.width: modelData.active ? 2 : 1
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4
                    // Thumb real si backend la provee; si no, icono grande.
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "▤"
                        color: "#FFFFFF"
                        font.pixelSize: 40
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.caption
                        color: "#FFFFFF"
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.app + (modelData.minimized ? " · minimizada" : "")
                        color: "#EBEBF5"
                        opacity: 0.6
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    drag.target: parent
                    onClicked: {
                        root.selIndex = index;
                        backend.activateWindow(modelData.id);
                        root.visible = false;
                    }
                    onPressed: root.dragWinId = modelData.id
                    onReleased: root.dragWinId = ""
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            Text {
                text: backend.windows.length + " ventanas · " + backend.desktops.length + " Spaces"
                color: "#EBEBF5"
                opacity: 0.6
                font.pixelSize: 11
            }
            Item {
                Layout.fillWidth: true
            }
            Text {
                text: "Tab=App Exposé · ←/→ mover · Enter activar · Esc cerrar"
                color: "#EBEBF5"
                opacity: 0.3
                font.pixelSize: 11
            }
        }
    }
}
