// Calendar.qml — popup calendario anclado al reloj (F3-T08, patrón Menu/CC).
// Scrim fullscreen (cierra al clic fuera, Esc) + popup derecha (x=der-8,y=26).
// Mes actual vía JS Date, grid 7 col L M X J V S D, navegación ‹ ›, hoy
// resaltado, cabecera mes/año. Tokens Nimbus; sin activos Apple. Eventos:
// placeholder (puntos días 1/15) sin fuente real.
import QtQuick
import org.kde.layershell as LayerShellQt

Item {
    id: root
    property bool opened: false
    property bool demo: false
    property int shownYear: new Date().getFullYear()
    property int shownMonth: new Date().getMonth()
    property var placeholderDays: [1, 15]
    function toggle() {
        opened ? close() : open();
    }
    function open() {
        var d = new Date();
        shownYear = d.getFullYear();
        shownMonth = d.getMonth();
        opened = true;
    }
    function close() {
        opened = false;
    }
    function prev() {
        if (shownMonth === 0) {
            shownMonth = 11;
            shownYear--;
        } else
            shownMonth--;
    }
    function next() {
        if (shownMonth === 11) {
            shownMonth = 0;
            shownYear++;
        } else
            shownMonth++;
    }
    function monthName(m) {
        return ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"][m];
    }
    function daysIn(m, y) {
        return new Date(y, m + 1, 0).getDate();
    }
    function leadBlanks(m, y) {
        return (new Date(y, m, 1).getDay() + 6) % 7;
    }
    function isToday(d) {
        var t = new Date();
        return d === t.getDate() && shownMonth === t.getMonth() && shownYear === t.getFullYear();
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
        title: "nimbus-cal-scrim"
        LayerShellQt.Window.layer: LayerShellQt.Window.LayerTop
        LayerShellQt.Window.exclusionZone: 0
        LayerShellQt.Window.keyboardInteractivity: LayerShellQt.Window.KeyboardInteractivityOnDemand
        LayerShellQt.Window.scope: "nimbus-cal-scrim"
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
        height: 470
        x: Screen.width - width - 8
        y: 26
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        color: "transparent"
        title: "nimbus-cal"
        LayerShellQt.Window.layer: LayerShellQt.Window.LayerTop
        LayerShellQt.Window.anchors: LayerShellQt.Window.AnchorTop | LayerShellQt.Window.AnchorRight
        LayerShellQt.Window.exclusionZone: 0
        LayerShellQt.Window.keyboardInteractivity: LayerShellQt.Window.KeyboardInteractivityNone
        LayerShellQt.Window.scope: "nimbus-cal"
        LayerShellQt.Window.activateOnShow: false
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: NimbusTokens.popupBg(NimbusTokens.dark)
            border.color: NimbusTokens.popupBorder(NimbusTokens.dark)
            border.width: 1
            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6
                Row {
                    width: parent.width
                    height: 28
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 6
                        // F11-T03: hover/pressed/foco tokenizados [HIG §2.5].
                        color: prevArea.pressed ? NimbusTokens.pressedFill(NimbusTokens.dark) : prevArea.containsMouse ? NimbusTokens.hoverFill(NimbusTokens.dark) : "transparent"
                        border.color: NimbusTokens.accentColor(NimbusTokens.dark)
                        border.width: prevArea.activeFocus ? NimbusTokens.states.focusRingPx : 0
                        objectName: "calPrev"
                        Text {
                            anchors.centerIn: parent
                            text: "‹"
                            font.pixelSize: 16
                            color: NimbusTokens.colors(NimbusTokens.dark).label
                        }
                        MouseArea {
                            id: prevArea
                            anchors.fill: parent
                            hoverEnabled: true
                            activeFocusOnTab: true
                            onClicked: root.prev()
                            Keys.onReturnPressed: root.prev()
                        }
                    }
                    Text {
                        width: parent.width - 56
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        height: 28
                        text: root.monthName(root.shownMonth) + " " + root.shownYear
                        font.family: NimbusTokens.fontFamily
                        font.pixelSize: NimbusTokens.type.t13b.size
                        font.weight: 700
                        color: NimbusTokens.colors(NimbusTokens.dark).label
                        objectName: "calHeader"
                    }
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 6
                        color: nextArea.pressed ? NimbusTokens.pressedFill(NimbusTokens.dark) : nextArea.containsMouse ? NimbusTokens.hoverFill(NimbusTokens.dark) : "transparent"
                        border.color: NimbusTokens.accentColor(NimbusTokens.dark)
                        border.width: nextArea.activeFocus ? NimbusTokens.states.focusRingPx : 0
                        objectName: "calNext"
                        Text {
                            anchors.centerIn: parent
                            text: "›"
                            font.pixelSize: 16
                            color: NimbusTokens.colors(NimbusTokens.dark).label
                        }
                        MouseArea {
                            id: nextArea
                            anchors.fill: parent
                            hoverEnabled: true
                            activeFocusOnTab: true
                            onClicked: root.next()
                            Keys.onReturnPressed: root.next()
                        }
                    }
                }
                Grid {
                    columns: 7
                    spacing: 2
                    width: parent.width
                    Repeater {
                        model: ["L", "M", "X", "J", "V", "S", "D"]
                        delegate: Text {
                            width: (280 - 20 - 12) / 7
                            height: 18
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            font.pixelSize: 11
                            font.weight: 600
                            color: NimbusTokens.faintText(NimbusTokens.dark)
                        }
                    }
                    Repeater {
                        id: blanks
                        model: root.leadBlanks(root.shownMonth, root.shownYear)
                        delegate: Item {
                            width: (280 - 20 - 12) / 7
                            height: 30
                        }
                    }
                    Repeater {
                        id: days
                        model: root.daysIn(root.shownMonth, root.shownYear)
                        delegate: Rectangle {
                            width: (280 - 20 - 12) / 7
                            height: 30
                            radius: 6
                            // F11-T03: hoy = selected accent configurable.
                            property bool today: root.isToday(index + 1)
                            color: today ? NimbusTokens.selectedFill(NimbusTokens.dark) : "transparent"
                            objectName: "calDay:" + (index + 1)
                            Column {
                                anchors.centerIn: parent
                                spacing: 1
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: index + 1
                                    font.pixelSize: 12
                                    color: parent.parent.today ? "white" : NimbusTokens.colors(NimbusTokens.dark).label
                                }
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 4
                                    height: 4
                                    radius: 2
                                    visible: root.placeholderDays.indexOf(index + 1) >= 0
                                    color: parent.parent.today ? Qt.rgba(1, 1, 1, 0.7) : NimbusTokens.subText(NimbusTokens.dark)
                                }
                            }
                        }
                    }
                }
                WeatherWidget {
                    id: wx
                }
            }
        }
    }
}
