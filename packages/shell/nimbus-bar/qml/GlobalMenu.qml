// GlobalMenu.qml — menú global Qt de la app activa (F3-T06).
// Modelo C++ `appMenu` (AppMenuModel, DBus com.canonical.dbusmenu).
// Sin menú (GTK/in-window, R-GTK): solo nombre de app en negrita.
// Patrón scrim+popup de Menu.qml: teclado OnDemand solo abierto;
// Esc/clic-fuera cierra. Drill-in para subniveles (gap: macOS usa
// submenú lateral; documentado en F3-T06-nested.md).
import QtQuick
import org.kde.layershell as LayerShellQt

Row {
    id: root
    objectName: "globalMenuObj"
    spacing: 12
    property bool demo: false
    property bool opened: false
    function toggleTop(id: int, label: string) {
        if (opened && appMenu.submenuTitle === label) {
            close();
            return;
        }
        appMenu.openSubmenu(id);
        opened = true;
    }
    function close() {
        opened = false;
        appMenu.closeMenu();
    }
    function activate(itemId: int, hasKids: bool, kidsCount: int, label: string) {
        if (hasKids || kidsCount > 0) {
            appMenu.openSubmenu(itemId);
        } else {
            appMenu.trigger(itemId);
            close();
        }
    }
    onOpenedChanged: {
        if (!opened)
            appMenu.closeMenu();
    }

    // Fila en la barra: nombre app (bold) + items de primer nivel.
    // (Los hijos viven directamente en el Row raíz.)
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: appMenu.appName
        font.family: NimbusTokens.fontFamily
        font.pixelSize: NimbusTokens.type.t13b.size
        font.weight: 700
        color: NimbusTokens.colors(NimbusTokens.dark).label
        objectName: "globalAppName"
    }
    Repeater {
        model: appMenu.topLevel
        delegate: Text {
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.label
            font.family: NimbusTokens.fontFamily
            font.pixelSize: NimbusTokens.type.t13.size
            color: modelData.enabled ? NimbusTokens.colors(NimbusTokens.dark).label : Qt.rgba(1, 1, 1, 0.35)
            objectName: "globalTop:" + modelData.label
            MouseArea {
                anchors.fill: parent
                enabled: modelData.enabled
                onClicked: root.toggleTop(modelData.id, modelData.label)
            }
        }
    }

    // Demo: al llegar un menú nuevo, reabrir el primer top-level (antes se
    // cierra el popup: la app activa cambió). Sin demo, un cambio de app
    // también cierra el popup abierto (comportamiento macOS).
    Connections {
        target: appMenu
        function onMenusChanged() {
            if (root.opened)
                root.close();
            if (root.demo && appMenu.hasMenu && appMenu.topLevel.length > 0) {
                var first = appMenu.topLevel[0];
                root.toggleTop(first.id, first.label);
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
        title: "nimbus-globalmenu-scrim"
        LayerShellQt.Window.layer: LayerShellQt.Window.LayerTop
        LayerShellQt.Window.exclusionZone: 0
        LayerShellQt.Window.keyboardInteractivity: LayerShellQt.Window.KeyboardInteractivityOnDemand
        LayerShellQt.Window.scope: "nimbus-globalmenu-scrim"
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
        width: 280
        height: Math.min(24 + subCol.children.length * 30, 560)
        x: 64
        y: 26
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        color: "transparent"
        title: "nimbus-globalmenu"
        LayerShellQt.Window.layer: LayerShellQt.Window.LayerTop
        LayerShellQt.Window.exclusionZone: 0
        LayerShellQt.Window.keyboardInteractivity: LayerShellQt.Window.KeyboardInteractivityNone
        LayerShellQt.Window.scope: "nimbus-globalmenu"
        LayerShellQt.Window.activateOnShow: false
        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Qt.rgba(0.13, 0.13, 0.15, 0.92)
            border.color: Qt.rgba(1, 1, 1, 0.14)
            border.width: 1
            objectName: "globalPopup"
            Column {
                id: subCol
                anchors.fill: parent
                anchors.margins: 6
                Text {
                    visible: appMenu.submenuTitle !== ""
                    text: appMenu.submenuTitle
                    font.pixelSize: 11
                    font.weight: 600
                    color: Qt.rgba(1, 1, 1, 0.5)
                    leftPadding: 8
                    bottomPadding: 2
                }
                Repeater {
                    model: appMenu.submenu
                    delegate: Loader {
                        width: subCol.width
                        sourceComponent: modelData.separator ? sepComp : rowComp
                        property var item: modelData
                    }
                }
            }
        }
    }

    Component {
        id: sepComp
        Rectangle {
            width: subCol.width
            height: 9
            color: "transparent"
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                height: 1
                color: Qt.rgba(1, 1, 1, 0.14)
            }
        }
    }
    Component {
        id: rowComp
        Rectangle {
            width: subCol.width
            height: 28
            radius: 6
            color: rowHover.containsMouse && item.enabled ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
            opacity: item.enabled ? 1.0 : 0.4
            objectName: "globalItem:" + item.label
            Row {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6
                Text {
                    visible: item.checked === true
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✓"
                    font.pixelSize: 12
                    color: "white"
                    width: 14
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: item.label
                    font.pixelSize: 13
                    color: "white"
                    elide: Text.ElideRight
                    width: parent.width - shortcutText.width - 30
                }
                Text {
                    id: shortcutText
                    anchors.verticalCenter: parent.verticalCenter
                    text: item.shortcut + (item.hasKids || (item.kids !== undefined && item.kids.length > 0) ? " ▶" : "")
                    font.pixelSize: 12
                    color: Qt.rgba(1, 1, 1, 0.55)
                }
            }
            MouseArea {
                id: rowHover
                anchors.fill: parent
                hoverEnabled: true
                enabled: item.enabled
                onClicked: {
                    var kc = (item.kids !== undefined) ? item.kids.length : 0;
                    root.activate(item.id, item.hasKids === true, kc, item.label);
                }
            }
        }
    }
}
