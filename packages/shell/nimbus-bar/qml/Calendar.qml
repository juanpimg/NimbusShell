// Calendar.qml — popover compacto de calendario anclado al reloj (F3-T08).
// Scrim fullscreen (cierra al clic fuera, Esc) + popup derecha (x=der-8,y=26).
// Mes actual vía JS Date, rejilla 6x7 L M X J V S D, navegación ‹ ›, hoy
// resaltado con círculo de acento y sábado/domingo atenuados. Sin eventos
// inventados: este popover no tiene fuente real de eventos, así que no
// dibuja puntos. Tokens Nimbus; sin activos Apple.
import QtQuick
import org.kde.layershell as LayerShellQt

Item {
    id: root

    property bool opened: false
    property bool demo: false
    property int shownYear: new Date().getFullYear()
    property int shownMonth: new Date().getMonth()
    // Popover compacto Tahoe (~300x368): cabecera 24, rejilla 6x7 de 30 px
    // y tiempo como pie. Alto fijo = sin hueco muerto entre rejilla y pie.
    readonly property int popupWidth: 300
    readonly property int popupHeight: 368
    readonly property real cellWidth: (popupWidth - 24) / 7
    readonly property int cellSize: 30

    function toggle() {
        opened ? close() : open();
    }

    function open() {
        today();
        opened = true;
    }

    function close() {
        opened = false;
    }

    function today() {
        var d = new Date();
        shownYear = d.getFullYear();
        shownMonth = d.getMonth();
    }

    function prev() {
        if (shownMonth === 0) {
            shownMonth = 11;
            shownYear--;
        } else {
            shownMonth--;
        }
    }

    function next() {
        if (shownMonth === 11) {
            shownMonth = 0;
            shownYear++;
        } else {
            shownMonth++;
        }
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
        width: root.popupWidth
        height: root.popupHeight
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
            radius: 20
            color: NimbusTokens.popupBg(NimbusTokens.dark)
            border.color: NimbusTokens.popupBorder(NimbusTokens.dark)
            border.width: 1

            // Specular top rim highlight (Tahoe Liquid Glass)
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 1
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 24
                height: 1
                radius: 0.5
                color: Qt.rgba(1, 1, 1, NimbusTokens.dark ? 0.38 : 0.6)
            }

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                // Cabecera: ‹ mes año ›. El título también vuelve a hoy.
                Item {
                    width: parent.width
                    height: 26

                    Rectangle {
                        width: 24
                        height: 24
                        radius: 6
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        color: prevArea.pressed ? NimbusTokens.pressedFill(NimbusTokens.dark) : prevArea.containsMouse ? NimbusTokens.hoverFill(NimbusTokens.dark) : "transparent"
                        border.color: NimbusTokens.accentColor(NimbusTokens.dark)
                        border.width: prevArea.activeFocus ? NimbusTokens.states.focusRingPx : 0
                        objectName: "calPrev"

                        Text {
                            anchors.centerIn: parent
                            text: "‹"
                            font.pixelSize: 15
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

                    Rectangle {
                        id: headerHover

                        anchors.centerIn: headerText
                        width: headerText.width + 16
                        height: 24
                        radius: 6
                        color: headerArea.containsMouse ? NimbusTokens.hoverFill(NimbusTokens.dark) : "transparent"
                        visible: headerArea.containsMouse || headerArea.activeFocus
                    }

                    Text {
                        id: headerText

                        anchors.centerIn: parent
                        width: parent.width - 64
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        height: 26
                        text: root.monthName(root.shownMonth) + " " + root.shownYear
                        font.family: NimbusTokens.fontFamily
                        font.pixelSize: NimbusTokens.type.t15.size
                        font.weight: NimbusTokens.type.t15.weightEmph
                        color: NimbusTokens.colors(NimbusTokens.dark).label
                        objectName: "calHeader"
                    }

                    MouseArea {
                        id: headerArea

                        anchors.fill: headerHover
                        hoverEnabled: true
                        activeFocusOnTab: true
                        onClicked: root.today()
                        Keys.onReturnPressed: root.today()
                    }

                    Rectangle {
                        width: 24
                        height: 24
                        radius: 6
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: nextArea.pressed ? NimbusTokens.pressedFill(NimbusTokens.dark) : nextArea.containsMouse ? NimbusTokens.hoverFill(NimbusTokens.dark) : "transparent"
                        border.color: NimbusTokens.accentColor(NimbusTokens.dark)
                        border.width: nextArea.activeFocus ? NimbusTokens.states.focusRingPx : 0
                        objectName: "calNext"

                        Text {
                            anchors.centerIn: parent
                            text: "›"
                            font.pixelSize: 15
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

                // Días de la semana; fines de semana atenuados.
                Grid {
                    columns: 7
                    width: parent.width

                    Repeater {
                        model: ["L", "M", "X", "J", "V", "S", "D"]

                        delegate: Text {
                            width: root.cellWidth
                            height: 16
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: modelData
                            font.family: NimbusTokens.fontFamily
                            font.pixelSize: NimbusTokens.type.t11.size
                            font.weight: NimbusTokens.type.t11.weight
                            color: index >= 5 ? NimbusTokens.faintText(NimbusTokens.dark) : NimbusTokens.subText(NimbusTokens.dark)
                        }
                    }
                }

                // Rejilla fija 6x7 (42 celdas): blancos al principio y al final
                // para que la altura no cambie entre meses.
                Grid {
                    columns: 7
                    width: parent.width

                    Repeater {
                        model: 42

                        delegate: Item {
                            property int dayNumber: index - root.leadBlanks(root.shownMonth, root.shownYear) + 1
                            property bool validDay: dayNumber >= 1 && dayNumber <= root.daysIn(root.shownMonth, root.shownYear)
                            property bool today: validDay && root.isToday(dayNumber)
                            property bool weekend: index % 7 >= 5

                            width: root.cellWidth
                            height: root.cellSize
                            objectName: validDay ? "calDay:" + dayNumber : ""

                            HoverHandler {
                                id: dayHover
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: root.cellSize - 2
                                height: root.cellSize - 2
                                radius: width / 2
                                // Hoy = círculo de acento; resto, hover sutil.
                                color: parent.today ? NimbusTokens.selectedFill(NimbusTokens.dark) : (parent.validDay && dayHover.hovered) ? NimbusTokens.hoverFill(NimbusTokens.dark) : "transparent"
                            }

                            Text {
                                anchors.centerIn: parent
                                text: parent.validDay ? parent.dayNumber : ""
                                font.family: NimbusTokens.fontFamily
                                font.pixelSize: NimbusTokens.type.t13.size
                                font.weight: parent.today ? NimbusTokens.type.t15.weightEmph : NimbusTokens.type.t13.weight
                                color: parent.today ? "white" : parent.weekend ? NimbusTokens.faintText(NimbusTokens.dark) : NimbusTokens.colors(NimbusTokens.dark).label
                            }
                        }
                    }
                }

                // Acción explícita para volver al mes actual.
                Item {
                    width: parent.width
                    height: 22

                    Rectangle {
                        id: todayButton

                        width: 52
                        height: 22
                        radius: 6
                        color: todayArea.pressed ? NimbusTokens.pressedFill(NimbusTokens.dark) : todayArea.containsMouse ? NimbusTokens.hoverFill(NimbusTokens.dark) : "transparent"
                        border.color: NimbusTokens.accentColor(NimbusTokens.dark)
                        border.width: todayArea.activeFocus ? NimbusTokens.states.focusRingPx : 0

                        Text {
                            anchors.centerIn: parent
                            text: qsTr("Hoy")
                            font.family: NimbusTokens.fontFamily
                            font.pixelSize: NimbusTokens.type.t12.size
                            font.weight: NimbusTokens.type.t15.weightEmph
                            color: NimbusTokens.accentColor(NimbusTokens.dark)
                        }

                        MouseArea {
                            id: todayArea

                            objectName: "calToday"
                            anchors.fill: parent
                            hoverEnabled: true
                            activeFocusOnTab: true
                            onClicked: root.today()
                            Keys.onReturnPressed: root.today()
                        }
                    }
                }

                // Pie compacto: tiempo real (o «—» honesto sin datos).
                WeatherWidget {
                    id: wx
                }
            }
        }
    }
}
