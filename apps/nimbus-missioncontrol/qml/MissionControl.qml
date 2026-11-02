// MissionControl.qml — overlay fullscreen Mission Control (F7 R-MC-CUSTOM).
// Fila de Spaces (crear + real) + grupos por app con tamaños + App Exposé.
// Animación slide/zoom 450ms; reduce-motion → fade 150ms. Tokens dark §2.1.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    objectName: "mcWindow"
    width: 1280
    height: 800
    visible: false // lo muestra main.cpp tras geometría+layer-shell
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
    color: "transparent"
    title: "Mission Control"

    property int activeSpace: backend.currentDesktop > 0 ? backend.currentDesktop - 1 : 0
    property int selIndex: 0
    property string dragWinId: ""
    property bool deskShown: false
    property bool introOn: false

    // Duraciones contrato §2.5: MC/Spaces 400-500ms; reduce-motion fade 150ms.
    property int animMs: backend.reduceMotion ? 150 : 450

    function spaceWindows() {
        var out = [];
        var desks = backend.desktops;
        if (desks.length === 0)
            return out;
        var idx = Math.min(root.activeSpace, desks.length - 1);
        var deskId = desks[idx].id;
        for (var i = 0; i < backend.windows.length; i++) {
            var w = backend.windows[i];
            if (w.desktop !== deskId && w.desktop !== "")
                continue;
            if (backend.exposeActiveAppOnly && w.app !== backend.currentApp)
                continue;
            out.push(w);
        }
        return out;
    }

    // Grupos por app (F7-T04) con índice plano para teclado/selección.
    function groupedWins() {
        var flat = root.spaceWindows();
        var groups = [];
        var map = {};
        for (var i = 0; i < flat.length; i++) {
            var w = flat[i];
            w.fi = i;
            if (map[w.app] === undefined) {
                map[w.app] = {
                    app: w.app,
                    wins: []
                };
                groups.push(map[w.app]);
            }
            map[w.app].wins.push(w);
        }
        return groups;
    }

    property var visibleWins: spaceWindows()
    property var grouped: groupedWins()

    function refreshVisible() {
        root.visibleWins = root.spaceWindows();
        root.grouped = root.groupedWins();
        root.selIndex = 0;
    }

    function restartIntro() {
        root.introOn = false;
        introArm.restart();
    }

    Timer {
        id: introArm
        interval: 40
        repeat: false
        onTriggered: root.introOn = true
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
        function onIntroChanged() {
            root.restartIntro();
        }
        function onMotionChanged() {
            root.restartIntro();
        }
    }

    Component.onCompleted: {
        backend.refresh();
        root.refreshVisible();
        root.restartIntro();
    }

    onActiveSpaceChanged: {
        root.refreshVisible();
        root.restartIntro();
    }
    onVisibleChanged: {
        if (root.visible)
            root.restartIntro();
    }

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

    // F7-T10: ocultar el overlay ANTES de activar. Si se activa primero,
    // KWin devuelve el foco a la ventana anterior al desmapear el overlay y
    // la activación se pierde (reproducido en out12). Script.run es síncrono.
    function activateAndClose(winId) {
        root.visible = false;
        backend.activateWindow(winId);
    }

    // Teclado vía Shortcut (Keys no se adjunta a Window, solo a Item).
    // F7-T10: la lógica vive en ui*() para que selftestKey la ejercite.
    function uiEsc() {
        root.visible = false;
    }
    function uiEnter() {
        if (root.visibleWins.length > 0)
            root.activateAndClose(root.visibleWins[root.selIndex].id);
    }
    function uiRight() {
        var n = root.visibleWins.length;
        if (n > 0)
            root.selIndex = (root.selIndex + 1) % n;
    }
    function uiLeft() {
        var n = root.visibleWins.length;
        if (n > 0)
            root.selIndex = (root.selIndex + n - 1) % n;
    }
    function uiExpose() {
        backend.toggleExpose();
    }
    function uiState() {
        return "visible=" + root.visible + " sel=" + root.selIndex + " expose=" + backend.exposeActiveAppOnly + " rm=" + backend.reduceMotion + " wins=" + root.visibleWins.length;
    }
    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: root.uiEsc()
    }
    Shortcut {
        sequences: ["Return", "Enter"]
        context: Qt.ApplicationShortcut
        onActivated: root.uiEnter()
    }
    Shortcut {
        sequence: "Right"
        context: Qt.ApplicationShortcut
        onActivated: root.uiRight()
    }
    Shortcut {
        sequence: "Left"
        context: Qt.ApplicationShortcut
        onActivated: root.uiLeft()
    }
    // F7-T07: Tab = App Exposé (pulido: cabecera muestra app + N de M).
    Shortcut {
        sequence: "Tab"
        context: Qt.ApplicationShortcut
        onActivated: root.uiExpose()
    }
    // F7-T07: Show Desktop (macOS F11); sin binds CTRL (R-HYPR).
    Shortcut {
        sequence: "F11"
        context: Qt.ApplicationShortcut
        onActivated: {
            root.deskShown = !root.deskShown;
            backend.showDesktop(root.deskShown);
        }
    }

    // Contenido con entrada slide/zoom (F7-T06).
    Item {
        id: content
        anchors.fill: parent
        opacity: root.introOn ? 1 : 0
        scale: root.introOn ? 1 : (backend.reduceMotion ? 1 : 0.96)
        Behavior on opacity {
            NumberAnimation {
                duration: root.animMs
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.animMs
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 12

            Text {
                text: exposeTitle()
                color: "#FFFFFF"
                font.pixelSize: 22
                font.bold: true
                Accessible.name: "Mission Control"
                function exposeTitle() {
                    if (backend.exposeActiveAppOnly)
                        return "App Exposé — " + backend.currentApp + " (" + root.visibleWins.length + " de " + backend.windows.length + ")";
                    return "Mission Control";
                }
            }

            // Fila de Spaces (F7-T01: crear + real vía VDM).
            RowLayout {
                id: spacesRow
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                spacing: 12
                // Slide de entrada (solo sin reduce-motion).
                transform: Translate {
                    x: root.introOn ? 0 : (backend.reduceMotion ? 0 : -24)
                    Behavior on x {
                        NumberAnimation {
                            duration: root.animMs
                            easing.type: Easing.OutCubic
                        }
                    }
                }
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
                        // Thumb del workspace en el Space activo (F7-T04).
                        Image {
                            anchors.fill: parent
                            visible: status === Image.Ready && index === root.activeSpace && backend.workspaceThumb !== ""
                            source: backend.workspaceThumb
                            fillMode: Image.PreserveAspectCrop
                            opacity: 0.55
                        }
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
                // Botón + CREA Space real (F7-T01, antes no-op).
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
                        onClicked: backend.createSpace()
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
            }

            Text {
                text: backend.hasThumbnails ? "Miniaturas en vivo (ScreenShot2)" : "Vista de iconos (ScreenShot2 sin imagen: fallback)"
                color: "#EBEBF5"
                opacity: 0.6
                font.pixelSize: 12
            }

            // Grupos por app con tamaños S/M/L (F7-T04).
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                Accessible.name: "Ventanas del Space activo por app"
                Column {
                    width: parent.width
                    spacing: 10
                    Repeater {
                        model: root.grouped
                        delegate: Column {
                            width: parent.width
                            spacing: 6
                            Text {
                                text: modelData.app + " · " + modelData.wins.length
                                color: "#0A84FF"
                                font.pixelSize: 12
                                font.bold: true
                            }
                            Flow {
                                width: parent.width
                                spacing: 12
                                Repeater {
                                    model: modelData.wins
                                    delegate: Rectangle {
                                        // Tamaños por área real (F7-T04).
                                        width: modelData.sizeClass === 2 ? 275 : (modelData.sizeClass === 1 ? 220 : 170)
                                        height: modelData.sizeClass === 2 ? 168 : (modelData.sizeClass === 1 ? 138 : 112)
                                        radius: 12
                                        color: modelData.fi === root.selIndex ? "#0A84FF" : "#2C2C2E"
                                        border.color: modelData.active ? "#0A84FF" : "#38383A"
                                        border.width: modelData.active ? 2 : 1
                                        opacity: root.introOn ? 1 : 0
                                        scale: root.introOn ? 1 : (backend.reduceMotion ? 1 : 0.92)
                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: root.animMs
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: root.animMs
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                        // Thumb real si existe; si no, icono.
                                        Image {
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            visible: status === Image.Ready && modelData.thumb !== ""
                                            source: modelData.thumb
                                            fillMode: Image.PreserveAspectCrop
                                        }
                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            spacing: 4
                                            visible: modelData.thumb === ""
                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: "▤"
                                                color: "#FFFFFF"
                                                font.pixelSize: modelData.sizeClass === 0 ? 28 : 40
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
                                                text: modelData.app + (modelData.minimized ? " · minimizada" : "") + " · " + modelData.w + "×" + modelData.h
                                                color: "#EBEBF5"
                                                opacity: 0.6
                                                font.pixelSize: 11
                                                elide: Text.ElideRight
                                            }
                                        }
                                        // Caption sobre thumb real.
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            height: 28
                                            radius: 6
                                            color: "#000000"
                                            opacity: 0.65
                                            visible: modelData.thumb !== ""
                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.caption
                                                color: "#FFFFFF"
                                                font.pixelSize: 11
                                                elide: Text.ElideRight
                                                width: parent.width - 8
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            drag.target: parent
                                            onClicked: {
                                                root.selIndex = modelData.fi;
                                                root.activateAndClose(modelData.id);
                                            }
                                            onPressed: root.dragWinId = modelData.id
                                            onReleased: root.dragWinId = ""
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                Text {
                    text: backend.windows.length + " ventanas · " + backend.desktops.length + " Spaces · " + (backend.reduceMotion ? "anim 150ms fade (RM)" : "anim 450ms slide/zoom")
                    color: "#EBEBF5"
                    opacity: 0.6
                    font.pixelSize: 11
                }
                Item {
                    Layout.fillWidth: true
                }
                Text {
                    text: "Tab=Exposé · F11=Show Desktop · ←/→ mover · Enter activar · Esc cerrar"
                    color: "#EBEBF5"
                    opacity: 0.3
                    font.pixelSize: 11
                }
            }
        }
    }
}
