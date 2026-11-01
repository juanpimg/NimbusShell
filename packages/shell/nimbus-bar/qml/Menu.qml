// Menu.qml — menú Apple anclado al logo N (F3-T04). Sin activos Apple.
// Raíz Item con 2 Windows layer-shell: scrim fullscreen (cierra al clic
// fuera) + popup (x=8,y=26, sin exclusiveZone). Teclado: OnDemand SOLO
// mientras el menú está abierto (cerrado → invisible → no roba nada);
// Esc cierra vía Shortcut. Iconos propios: círculos con inicial.
import QtQuick
import org.kde.layershell as LayerShellQt

Item {
    id: root
    objectName: "appleMenuObj"
    property bool opened: false
    property bool demo: false
    property string pendingAction: ""
    property string pendingLabel: ""
    function toggle() {
        opened = !opened;
    }
    function open() {
        opened = true;
    }
    function close() {
        confirmBox.visible = false;
        pendingAction = "";
        opened = false;
    }
    function askConfirm(cmd: string, label: string) {
        pendingAction = cmd;
        pendingLabel = label;
        confirmBox.visible = true;
    }
    function doRun(cmd: string) {
        if (!demo)
            runner.run(cmd);
        console.log("menu: run " + cmd + (demo ? " (demo, no ejecutado)" : ""));
        close();
    }
    // F3-T04 fix: recorre los 7 items y loguea sin ejecutar nada.
    function logAllActions() {
        for (var i = 0; i < actionModel.count; i++) {
            var it = actionModel.get(i);
            runner.logAction(i, it.cmd);
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
        title: "nimbus-menu-scrim"
        LayerShellQt.Window.layer: LayerShellQt.Window.LayerTop
        LayerShellQt.Window.exclusionZone: 0
        LayerShellQt.Window.keyboardInteractivity: LayerShellQt.Window.KeyboardInteractivityOnDemand
        LayerShellQt.Window.scope: "nimbus-menu-scrim"
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
        width: 248
        height: confirmBox.visible ? 380 : 340
        x: 8
        y: 26
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        color: "transparent"
        title: "nimbus-menu"
        LayerShellQt.Window.layer: LayerShellQt.Window.LayerTop
        LayerShellQt.Window.exclusionZone: 0
        LayerShellQt.Window.keyboardInteractivity: LayerShellQt.Window.KeyboardInteractivityNone
        LayerShellQt.Window.scope: "nimbus-menu"
        LayerShellQt.Window.activateOnShow: false
        Rectangle {
            anchors.fill: parent
            radius: 10
            color: NimbusTokens.popupBg(NimbusTokens.dark)
            border.color: NimbusTokens.popupBorder(NimbusTokens.dark)
            border.width: 1
            Column {
                anchors.fill: parent
                anchors.margins: 6
                Repeater {
                    id: rows
                    model: ListModel {
                        id: actionModel
                        ListElement {
                            label: "Acerca de Nimbus"
                            cmd: "nimbus-about"
                            glyph: "N"
                        }
                        ListElement {
                            label: "Ayuda de Nimbus"
                            cmd: "nimbus-help"
                            glyph: "?"
                        }
                        ListElement {
                            label: "Ajustes del sistema…"
                            cmd: "systemsettings"
                            glyph: "S"
                        }
                        ListElement {
                            label: "Dormir"
                            cmd: "systemctl suspend"
                            glyph: "Z"
                        }
                        ListElement {
                            label: "Bloquear"
                            cmd: "loginctl lock-session"
                            glyph: "L"
                        }
                        ListElement {
                            label: "Cerrar sesión"
                            cmd: "loginctl terminate-session"
                            glyph: "C"
                        }
                        ListElement {
                            label: "Reiniciar…"
                            cmd: "systemctl reboot"
                            glyph: "R"
                        }
                        ListElement {
                            label: "Apagar…"
                            cmd: "systemctl poweroff"
                            glyph: "O"
                        }
                    }
                    delegate: Rectangle {
                        width: rows.parent.width
                        height: 32
                        radius: 6
                        // F11-T03: hover = selected accent (macOS), pressed =
                        // iluminación interna, foco = anillo 2px [HIG §2.5].
                        property bool sel: rowHover.containsMouse
                        color: rowHover.pressed ? NimbusTokens.pressedFill(NimbusTokens.dark) : sel ? NimbusTokens.selectedFill(NimbusTokens.dark) : "transparent"
                        border.color: NimbusTokens.accentColor(NimbusTokens.dark)
                        border.width: rowHover.activeFocus ? NimbusTokens.states.focusRingPx : 0
                        objectName: "menuItem:" + label
                        function activateRow() {
                            if (model.label === "Reiniciar…" || model.label === "Apagar…")
                                root.askConfirm(model.cmd, model.label);
                            else if (model.cmd !== "")
                                root.doRun(model.cmd);
                            else
                                root.close();
                        }
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            spacing: 10
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                anchors.verticalCenter: parent.verticalCenter
                                color: parent.parent.sel ? Qt.rgba(1, 1, 1, 0.25) : NimbusTokens.hoverFill(NimbusTokens.dark)
                                Text {
                                    anchors.centerIn: parent
                                    text: glyph
                                    font.pixelSize: 11
                                    font.weight: 700
                                    color: parent.parent.parent.sel ? "white" : NimbusTokens.colors(NimbusTokens.dark).label
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: label
                                font.pixelSize: 13
                                color: parent.parent.sel ? "white" : NimbusTokens.colors(NimbusTokens.dark).label
                            }
                        }
                        MouseArea {
                            id: rowHover
                            anchors.fill: parent
                            hoverEnabled: true
                            activeFocusOnTab: true
                            onClicked: parent.activateRow()
                            Keys.onReturnPressed: parent.activateRow()
                        }
                    }
                }
                Rectangle {
                    id: confirmBox
                    width: parent.width
                    visible: false
                    height: visible ? 60 : 0
                    color: "transparent"
                    objectName: "menuConfirm"
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.top: parent.top
                        text: "¿" + root.pendingLabel + "?"
                        font.pixelSize: 12
                        color: NimbusTokens.colors(NimbusTokens.dark).destructive
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        spacing: 8
                        Rectangle {
                            width: 64
                            height: 26
                            radius: 6
                            color: NimbusTokens.colors(NimbusTokens.dark).bg2
                            border.color: NimbusTokens.popupBorder(NimbusTokens.dark)
                            border.width: noBtn.activeFocus ? NimbusTokens.states.focusRingPx : 0
                            Text {
                                anchors.centerIn: parent
                                text: "No"
                                color: NimbusTokens.colors(NimbusTokens.dark).label
                                font.pixelSize: 12
                            }
                            MouseArea {
                                id: noBtn
                                anchors.fill: parent
                                activeFocusOnTab: true
                                onClicked: confirmBox.visible = false
                                Keys.onReturnPressed: confirmBox.visible = false
                            }
                        }
                        Rectangle {
                            width: 64
                            height: 26
                            radius: 6
                            color: NimbusTokens.colors(NimbusTokens.dark).destructive
                            border.color: NimbusTokens.accentColor(NimbusTokens.dark)
                            border.width: yesBtn.activeFocus ? NimbusTokens.states.focusRingPx : 0
                            Text {
                                anchors.centerIn: parent
                                text: "Sí"
                                color: "white"
                                font.pixelSize: 12
                            }
                            MouseArea {
                                id: yesBtn
                                anchors.fill: parent
                                activeFocusOnTab: true
                                onClicked: root.doRun(root.pendingAction)
                                Keys.onReturnPressed: root.doRun(root.pendingAction)
                            }
                        }
                    }
                }
            }
        }
    }
}
