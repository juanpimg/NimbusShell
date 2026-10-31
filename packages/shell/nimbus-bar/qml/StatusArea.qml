// StatusArea.qml — system tray SNI en la barra (F3-T07). Sin activos Apple.
// Iconos 16px a la derecha (antes del reloj): clic izquierdo = Activate,
// clic derecho = menú dbusmenu (fetch vía modelo); tooltip con Title.
// Requiere context props: `trayModel` (StatusNotifierModel) y
// `trayOpenMenu` (fila a auto-abrir, -1 = no; flag --tray-open-menu).
import QtQuick
import org.kde.layershell as LayerShellQt

Item {
    id: root
    property int autoOpenRow: -1
    property int menuRow: -1
    property var menuItems: []
    property bool menuOpened: false
    property bool autoOpened: false
    width: trayRow.width
    height: 16

    function openMenu(row: int) {
        if (row < 0 || row >= trayModel.count)
            return;
        menuRow = row;
        menuItems = trayModel.fetchMenu(row);
        menuOpened = menuItems.length > 0;
    }
    function closeMenu() {
        menuOpened = false;
        menuRow = -1;
        menuItems = [];
    }
    function trigger(id: int) {
        trayModel.triggerMenuAction(menuRow, id);
        closeMenu();
    }

    Connections {
        target: trayModel
        function onCountChanged() {
            if (root.autoOpenRow >= 0 && !root.autoOpened && trayModel.count > root.autoOpenRow)
                root.autoOpened = true; // el Timer hace el open (defer)
            // F3-T07-fix: si la fila del menú abierto desaparece
            // (unregister), se cierra el popup (evita índice colgado).
            if (root.menuOpened && root.menuRow >= trayModel.count)
                root.closeMenu();
        }
    }
    // Auto-apertura diferida (flag --tray-open-menu, solo captura nested).
    Timer {
        interval: 500
        running: root.autoOpenRow >= 0 && !root.autoOpened
        repeat: true
        onTriggered: {
            if (trayModel.count > root.autoOpenRow) {
                root.autoOpened = true;
                root.openMenu(root.autoOpenRow);
            }
        }
    }

    Row {
        id: trayRow
        spacing: 6
        Repeater {
            model: trayModel
            delegate: Item {
                id: cell
                required property int index
                required property string title
                required property string tooltip
                required property string iconUid
                required property bool hasMenu
                width: 16
                height: 16
                Accessible.name: title
                Image {
                    anchors.fill: parent
                    // uid cambia al refrescar -> recarga del provider.
                    source: "image://sni/" + cell.iconUid
                    cache: false
                    smooth: true
                }
                // Tooltip propio (Title — texto).
                Rectangle {
                    id: tip
                    visible: tipArea.containsMouse && cell.tooltip !== ""
                    anchors.bottom: cell.top
                    anchors.bottomMargin: 6
                    anchors.horizontalCenter: cell.horizontalCenter
                    width: tipText.width + 12
                    height: tipText.height + 8
                    radius: 6
                    color: Qt.rgba(0.15, 0.15, 0.16, 0.95)
                    border.color: Qt.rgba(1, 1, 1, 0.2)
                    border.width: 1
                    Text {
                        id: tipText
                        anchors.centerIn: parent
                        text: cell.tooltip
                        font.family: NimbusTokens.fontFamily
                        font.pixelSize: NimbusTokens.type.t12.size
                        color: "white"
                    }
                }
                MouseArea {
                    id: tipArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            if (cell.hasMenu)
                                root.openMenu(cell.index);
                            else
                                trayModel.contextMenu(cell.index);
                        } else {
                            trayModel.activate(cell.index);
                        }
                    }
                }
            }
        }
    }

    // Popup dbusmenu (scrim + ventana, mismo patrón que Menu.qml).
    Window {
        id: scrim
        visible: root.menuOpened
        width: Screen.width
        height: Screen.height
        x: 0
        y: 0
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        color: "transparent"
        title: "nimbus-tray-scrim"
        LayerShellQt.Window.layer: LayerShellQt.Window.LayerTop
        LayerShellQt.Window.exclusionZone: 0
        LayerShellQt.Window.keyboardInteractivity: LayerShellQt.Window.KeyboardInteractivityOnDemand
        LayerShellQt.Window.scope: "nimbus-tray-scrim"
        LayerShellQt.Window.activateOnShow: false
        MouseArea {
            anchors.fill: parent
            onClicked: root.closeMenu()
        }
        Shortcut {
            sequence: "Escape"
            enabled: root.menuOpened
            onActivated: root.closeMenu()
        }
    }
    Window {
        id: popup
        visible: root.menuOpened
        width: 200
        height: Math.max(32, root.menuItems.length * 28 + 16)
        x: Screen.width - width - 8
        y: 26
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        color: "transparent"
        title: "nimbus-tray-menu"
        objectName: "trayMenuPopup"
        LayerShellQt.Window.anchors: LayerShellQt.Window.AnchorTop | LayerShellQt.Window.AnchorRight
        LayerShellQt.Window.layer: LayerShellQt.Window.LayerTop
        LayerShellQt.Window.exclusionZone: 0
        LayerShellQt.Window.keyboardInteractivity: LayerShellQt.Window.KeyboardInteractivityNone
        LayerShellQt.Window.scope: "nimbus-tray-menu"
        LayerShellQt.Window.activateOnShow: false
        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Qt.rgba(0.16, 0.16, 0.18, 0.96)
            border.color: Qt.rgba(1, 1, 1, 0.18)
            border.width: 1
            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 0
                Repeater {
                    model: root.menuItems
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width
                        height: 28
                        radius: 6
                        color: hover.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            font.family: NimbusTokens.fontFamily
                            font.pixelSize: NimbusTokens.type.t13.size
                            color: modelData.enabled ? "white" : Qt.rgba(1, 1, 1, 0.4)
                        }
                        MouseArea {
                            id: hover
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: modelData.enabled
                            onClicked: root.trigger(modelData.id)
                        }
                    }
                }
            }
        }
    }
}
