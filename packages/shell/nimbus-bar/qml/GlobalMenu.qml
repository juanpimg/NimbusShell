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

    objectName: "globalMenuObj"
    spacing: 12
    onOpenedChanged: {
        if (opened && demo)
            console.log("globalmenu: popup " + popup.width + "x" + popup.height + " at " + popup.x + "," + popup.y);

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

        // F11-T03: pill hover/pressed + anillo foco; disabled tokenizado.
        delegate: Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: topLbl.width + 12
            height: 22
            radius: 5
            color: topArea.pressed ? NimbusTokens.pressedFill(NimbusTokens.dark) : topArea.containsMouse ? NimbusTokens.hoverFill(NimbusTokens.dark) : "transparent"
            border.color: NimbusTokens.accentColor(NimbusTokens.dark)
            border.width: topArea.activeFocus ? NimbusTokens.states.focusRingPx : 0
            opacity: modelData.enabled ? 1 : NimbusTokens.states.disabledOpacity[0]
            objectName: "globalTop:" + modelData.label

            Text {
                id: topLbl

                anchors.centerIn: parent
                text: modelData.label
                font.family: NimbusTokens.fontFamily
                font.pixelSize: NimbusTokens.type.t13.size
                color: modelData.enabled ? NimbusTokens.colors(NimbusTokens.dark).label : NimbusTokens.disabledText(NimbusTokens.dark)
            }

            MouseArea {
                id: topArea

                anchors.fill: parent
                hoverEnabled: true
                activeFocusOnTab: true
                enabled: modelData.enabled
                onClicked: root.toggleTop(modelData.id, modelData.label)
                Keys.onReturnPressed: root.toggleTop(modelData.id, modelData.label)
            }
        }
    }

    // Demo: al llegar un menú nuevo, reabrir el primer top-level (antes se
    // cierra el popup: la app activa cambió). Sin demo, un cambio de app
    // también cierra el popup abierto (comportamiento macOS).
    Connections {
        function onMenusChanged() {
            if (root.opened)
                root.close();

            if (root.demo && appMenu.hasMenu && appMenu.topLevel.length > 0) {
                var first = appMenu.topLevel[0];
                root.toggleTop(first.id, first.label);
            }
        }

        target: appMenu
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

    // F3-T06-fix: en layer-shell la geometría explícita (x/y/width) se
    // ignora sin anclas (el popup salía a pantalla completa); con
    // Top|Left se respeta el tamaño 280 (patrón de F3-T05).
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
        LayerShellQt.Window.anchors: LayerShellQt.Window.AnchorTop | LayerShellQt.Window.AnchorLeft
        LayerShellQt.Window.exclusionZone: 0
        LayerShellQt.Window.keyboardInteractivity: LayerShellQt.Window.KeyboardInteractivityNone
        LayerShellQt.Window.scope: "nimbus-globalmenu"
        LayerShellQt.Window.activateOnShow: false

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: NimbusTokens.popupBg(NimbusTokens.dark)
            border.color: NimbusTokens.popupBorder(NimbusTokens.dark)
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
                    color: NimbusTokens.faintText(NimbusTokens.dark)
                    leftPadding: 8
                    bottomPadding: 2
                }

                Repeater {
                    model: appMenu.submenu

                    delegate: Loader {
                        property var item: modelData

                        width: subCol.width
                        sourceComponent: modelData.separator ? sepComp : rowComp
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
                color: NimbusTokens.popupBorder(NimbusTokens.dark)
            }
        }
    }

    Component {
        id: rowComp

        Rectangle {
            // F11-T03: hover = accent (macOS), pressed interno, foco 2px,
            // disabled tokenizado sin hover [HIG §2.5].
            property bool sel: rowHover.containsMouse && item.enabled

            function activateRow() {
                var kc = (item.kids !== undefined) ? item.kids.length : 0;
                root.activate(item.id, item.hasKids === true, kc, item.label);
            }

            width: subCol.width
            height: 28
            radius: 6
            color: !item.enabled ? "transparent" : rowHover.pressed ? NimbusTokens.pressedFill(NimbusTokens.dark) : sel ? NimbusTokens.selectedFill(NimbusTokens.dark) : "transparent"
            border.color: NimbusTokens.accentColor(NimbusTokens.dark)
            border.width: rowHover.activeFocus ? NimbusTokens.states.focusRingPx : 0
            opacity: item.enabled ? 1 : NimbusTokens.states.disabledOpacity[0]
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
                    color: parent.parent.sel ? "white" : NimbusTokens.colors(NimbusTokens.dark).label
                    width: 14
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: item.label
                    font.pixelSize: 13
                    color: parent.parent.sel ? "white" : NimbusTokens.colors(NimbusTokens.dark).label
                    elide: Text.ElideRight
                    width: parent.width - shortcutText.width - 30
                }

                Text {
                    id: shortcutText

                    anchors.verticalCenter: parent.verticalCenter
                    text: item.shortcut + (item.hasKids || (item.kids !== undefined && item.kids.length > 0) ? " ▶" : "")
                    font.pixelSize: 12
                    color: parent.parent.sel ? Qt.rgba(1, 1, 1, 0.75) : NimbusTokens.subText(NimbusTokens.dark)
                }
            }

            MouseArea {
                id: rowHover

                anchors.fill: parent
                hoverEnabled: true
                activeFocusOnTab: true
                enabled: item.enabled
                onClicked: parent.activateRow()
                Keys.onReturnPressed: parent.activateRow()
            }
        }
    }
}
