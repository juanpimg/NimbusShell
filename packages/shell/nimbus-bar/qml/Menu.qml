// Menu.qml — menú Apple anclado al logo N (F3-T04). Sin activos Apple.
// Raíz Item con 2 Windows layer-shell: scrim fullscreen (cierra al clic
// fuera) + popup (x=8,y=26, sin exclusiveZone). Teclado: OnDemand SOLO
// mientras el menú está abierto (cerrado → invisible → no roba nada);
// Esc cierra vía Shortcut. Iconos propios: círculos con inicial.
import QtQuick
import org.kde.layershell as LayerShellQt

Item {
    id: root

    property bool opened: false
    property bool demo: false
    property string pendingAction: ""
    property string pendingLabel: ""
    readonly property alias actionModel: actionModel

    signal actionTriggered(string cmd, string label)

    function toggle() {
        opened = !opened;
    }

    function open() {
        opened = true;
    }

    function close() {
        confirmBox.visible = false;
        pendingAction = "";
        pendingLabel = "";
        opened = false;
    }

    function askConfirm(cmd: string, label: string) {
        pendingAction = cmd;
        pendingLabel = label;
        confirmBox.visible = true;
    }

    function doRun(cmd: string, label) {
        var lbl = (label && label !== "") ? label : pendingLabel;
        actionTriggered(cmd, lbl);
        if (!demo && typeof runner !== "undefined")
            runner.run(cmd);

        console.log("menu: run " + cmd + (demo ? " (demo, no ejecutado)" : ""));
        close();
    }

    // F3-T04 fix: recorre los 9 items y loguea sin ejecutar nada.
    function logAllActions() {
        for (var i = 0; i < actionModel.count; i++) {
            var it = actionModel.get(i);
            if (typeof runner !== "undefined")
                runner.logAction(i, it.cmd);
        }
    }

    objectName: "appleMenuObj"

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
        height: menuColumn.implicitHeight + 12
        x: 8
        y: 26
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        color: "transparent"
        title: "nimbus-menu"
        // popup por ENCIMA del scrim (Top); si ambos son Top, el scrim
        // fullscreen puede recibir el clic y cerrar sin ejecutar la accion.
        LayerShellQt.Window.layer: LayerShellQt.Window.LayerOverlay
        LayerShellQt.Window.exclusionZone: 0
        LayerShellQt.Window.keyboardInteractivity: LayerShellQt.Window.KeyboardInteractivityNone
        LayerShellQt.Window.scope: "nimbus-menu"
        LayerShellQt.Window.activateOnShow: false

        Rectangle {
            anchors.fill: parent
            radius: 16
            // F11-T02: alpha de vidrio; el 0.94 denso del token tapaba el
            // blur/refracción de Glass. El texto sigue legible sobre el tinte.
            color: {
                var c = NimbusTokens.popupBg(NimbusTokens.dark);
                return Qt.rgba(c.r, c.g, c.b, 0.64);
            }
            border.color: NimbusTokens.popupBorder(NimbusTokens.dark)
            border.width: 1

            // Specular top rim highlight (Tahoe Liquid Glass)
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 1
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 16
                height: 1
                radius: 0.5
                color: Qt.rgba(1, 1, 1, NimbusTokens.dark ? 0.38 : 0.6)
            }

            Column {
                id: menuColumn

                anchors.fill: parent
                anchors.margins: 6

                Repeater {
                    id: rows

                    model: ListModel {
                        id: actionModel

                        ListElement {
                            label: "Acerca de Nimbus"
                            cmd: "nimbus-about"
                            icon: "logo"
                            group: 0
                        }

                        ListElement {
                            label: "Ayuda de Nimbus"
                            cmd: "nimbus-help"
                            icon: "help"
                            group: 1
                        }

                        ListElement {
                            label: "Reloj"
                            cmd: "nimbus-clock"
                            icon: "clock"
                            group: 2
                        }

                        ListElement {
                            label: "Ajustes del sistema…"
                            cmd: "systemsettings kcm_nimbus"
                            icon: "gear"
                            group: 3
                        }

                        ListElement {
                            label: "Dormir"
                            cmd: "qdbus6 org.freedesktop.PowerManagement /PowerManagement Suspend || systemctl suspend"
                            icon: "moon"
                            group: 4
                        }

                        ListElement {
                            label: "Bloquear"
                            cmd: "qdbus6 org.freedesktop.ScreenSaver /ScreenSaver Lock || loginctl lock-session"
                            icon: "lock"
                            group: 4
                        }

                        ListElement {
                            label: "Cerrar sesión"
                            cmd: "qdbus6 org.kde.Shutdown /Shutdown org.kde.Shutdown.logout || loginctl terminate-session \"\""
                            icon: "logout"
                            group: 4
                            destructive: true
                        }

                        ListElement {
                            label: "Reiniciar…"
                            cmd: "qdbus6 org.kde.Shutdown /Shutdown org.kde.Shutdown.logoutAndReboot || systemctl reboot"
                            icon: "restart"
                            group: 5
                            destructive: true
                        }

                        ListElement {
                            label: "Apagar…"
                            cmd: "qdbus6 org.kde.Shutdown /Shutdown org.kde.Shutdown.logoutAndShutdown || systemctl poweroff"
                            icon: "power"
                            group: 5
                            destructive: true
                        }
                    }

                    delegate: Item {
                        property bool separatorVisible: index > 0 && model.group !== actionModel.get(index - 1).group

                        function activateRow() {
                            var isDestructive = (typeof model.destructive !== "undefined" && model.destructive) || model.label === "Reiniciar…" || model.label === "Apagar…" || model.label === "Cerrar sesión";
                            if (isDestructive)
                                root.askConfirm(model.cmd, model.label);
                            else if (model.cmd !== "")
                                root.doRun(model.cmd, model.label);
                            else
                                root.close();
                        }

                        width: rows.parent.width
                        height: 28 + (separatorVisible ? 7 : 0)

                        Rectangle {
                            visible: parent.separatorVisible
                            anchors.top: parent.top
                            anchors.topMargin: 3
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: NimbusTokens.popupBorder(NimbusTokens.dark)
                        }

                        Rectangle {
                            id: rowBg

                            // F11-T03: hover = selected accent (macOS), pressed =
                            // iluminación interna, foco = anillo 2px [HIG §2.5].
                            property bool sel: rowHover.containsMouse

                            anchors.top: parent.top
                            anchors.topMargin: parent.separatorVisible ? 7 : 0
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 28
                            radius: 6
                            color: rowHover.pressed ? NimbusTokens.pressedFill(NimbusTokens.dark) : sel ? NimbusTokens.selectedFill(NimbusTokens.dark) : "transparent"
                            border.color: NimbusTokens.accentColor(NimbusTokens.dark)
                            border.width: rowHover.activeFocus ? NimbusTokens.states.focusRingPx : 0
                            objectName: "menuItem:" + model.label

                            Rectangle {
                                width: 16
                                height: 16
                                radius: 8
                                anchors.left: parent.left
                                anchors.leftMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                color: parent.sel ? Qt.rgba(1, 1, 1, 0.25) : NimbusTokens.hoverFill(NimbusTokens.dark)

                                MenuGlyph {
                                    anchors.centerIn: parent
                                    width: 13
                                    height: 13
                                    kind: model.icon
                                    stroke: parent.parent.sel ? "white" : NimbusTokens.colors(NimbusTokens.dark).label
                                }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 30
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: model.label
                                elide: Text.ElideRight
                                font.pixelSize: 13
                                color: parent.sel ? "white" : NimbusTokens.colors(NimbusTokens.dark).label
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
                        text: "¿" + root.pendingLabel.replace(/…$/, "") + "?"
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
                                onClicked: root.doRun(root.pendingAction, root.pendingLabel)
                                Keys.onReturnPressed: root.doRun(root.pendingAction, root.pendingLabel)
                            }
                        }
                    }
                }
            }
        }
    }

    // Iconos de línea del menú (Canvas; sin activos Apple ni fuentes de iconos).
    component MenuGlyph: Canvas {
        id: mg

        property string kind: "info"
        property color stroke: "#FFFFFF"

        width: 13
        height: 13
        onKindChanged: requestPaint()
        onStrokeChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var w = width;
            var h = height;
            var cx = w / 2;
            var cy = h / 2;
            ctx.strokeStyle = mg.stroke;
            ctx.fillStyle = mg.stroke;
            ctx.lineWidth = 1.5;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            if (kind === "logo") {
                ctx.beginPath();
                ctx.moveTo(w * 0.3, h * 0.82);
                ctx.lineTo(w * 0.3, h * 0.18);
                ctx.lineTo(w * 0.7, h * 0.82);
                ctx.lineTo(w * 0.7, h * 0.18);
                ctx.stroke();
            } else if (kind === "info") {
                ctx.beginPath();
                ctx.arc(cx, cy, w * 0.38, 0, Math.PI * 2);
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(cx, h * 0.34, 0.8, 0, Math.PI * 2);
                ctx.fill();
                ctx.beginPath();
                ctx.moveTo(cx, h * 0.46);
                ctx.lineTo(cx, h * 0.72);
                ctx.stroke();
            } else if (kind === "help") {
                ctx.beginPath();
                ctx.arc(cx, cy, w * 0.38, 0, Math.PI * 2);
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(cx, h * 0.4, w * 0.15, Math.PI * 0.85, Math.PI * 2.15);
                ctx.stroke();
                ctx.beginPath();
                ctx.moveTo(cx, h * 0.55);
                ctx.lineTo(cx, h * 0.62);
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(cx, h * 0.74, 0.8, 0, Math.PI * 2);
                ctx.fill();
            } else if (kind === "clock") {
                ctx.beginPath();
                ctx.arc(cx, cy, w * 0.38, 0, Math.PI * 2);
                ctx.stroke();
                ctx.beginPath();
                ctx.moveTo(cx, cy);
                ctx.lineTo(cx, h * 0.3);
                ctx.moveTo(cx, cy);
                ctx.lineTo(w * 0.66, h * 0.58);
                ctx.stroke();
            } else if (kind === "gear") {
                ctx.beginPath();
                ctx.arc(cx, cy, w * 0.3, 0, Math.PI * 2);
                ctx.stroke();
                for (var i = 0; i < 6; ++i) {
                    var a = i * Math.PI / 3;
                    ctx.beginPath();
                    ctx.moveTo(cx + Math.cos(a) * w * 0.33, cy + Math.sin(a) * h * 0.33);
                    ctx.lineTo(cx + Math.cos(a) * w * 0.44, cy + Math.sin(a) * h * 0.44);
                    ctx.stroke();
                }
                ctx.beginPath();
                ctx.arc(cx, cy, w * 0.08, 0, Math.PI * 2);
                ctx.fill();
            } else if (kind === "moon") {
                ctx.beginPath();
                ctx.moveTo(w * 0.68, h * 0.2);
                ctx.quadraticCurveTo(w * 0.22, h * 0.5, w * 0.68, h * 0.8);
                ctx.quadraticCurveTo(w * 0.48, h * 0.5, w * 0.68, h * 0.2);
                ctx.stroke();
            } else if (kind === "lock") {
                ctx.beginPath();
                ctx.roundedRect(w * 0.24, h * 0.42, w * 0.52, h * 0.38, 2);
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(cx, h * 0.42, w * 0.2, Math.PI, Math.PI * 2);
                ctx.stroke();
            } else if (kind === "logout") {
                ctx.beginPath();
                ctx.roundedRect(w * 0.2, h * 0.18, w * 0.38, h * 0.64, 2);
                ctx.stroke();
                ctx.beginPath();
                ctx.moveTo(w * 0.52, h * 0.5);
                ctx.lineTo(w * 0.82, h * 0.5);
                ctx.moveTo(w * 0.7, h * 0.38);
                ctx.lineTo(w * 0.82, h * 0.5);
                ctx.lineTo(w * 0.7, h * 0.62);
                ctx.stroke();
            } else if (kind === "restart") {
                ctx.beginPath();
                ctx.arc(cx, cy, w * 0.36, Math.PI * 0.35, Math.PI * 1.75);
                ctx.stroke();
                ctx.beginPath();
                ctx.moveTo(w * 0.74, h * 0.3);
                ctx.lineTo(w * 0.84, h * 0.46);
                ctx.lineTo(w * 0.66, h * 0.46);
                ctx.stroke();
            } else if (kind === "power") {
                ctx.beginPath();
                ctx.arc(cx, h * 0.55, w * 0.34, Math.PI * 0.75, Math.PI * 2.25);
                ctx.stroke();
                ctx.beginPath();
                ctx.moveTo(cx, h * 0.16);
                ctx.lineTo(cx, h * 0.52);
                ctx.stroke();
            }
        }
    }
}
