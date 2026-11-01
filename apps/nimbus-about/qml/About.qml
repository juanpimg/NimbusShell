// About.qml — F10-T01. Ventana 520x420 sobre glass, logo N propio
// (Texto, sin assets Apple), tokens Tahoe contrato §2 [HIG].
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    objectName: "aboutWindow"
    width: 520
    height: 420
    minimumWidth: 480
    minimumHeight: 380
    visible: true
    title: "Acerca de Nimbus"
    color: "transparent"

    property bool isDark: true
    property var c: ({
            "label": "#FFFFFF",
            "label2": "#EBEBF5",
            "bg": "#000000",
            "bgElevated": "#2C2C2E",
            "bg2": "#1C1C1E",
            "accent": "#0A84FF",
            "separator": "#38383A"
        })

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: root.c.bgElevated
        border.color: root.c.separator
        border.width: 1
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 8
            RowLayout {
                spacing: 16
                Rectangle {
                    width: 64
                    height: 64
                    radius: 14
                    color: root.c.accent
                    Text {
                        anchors.centerIn: parent
                        text: "N"
                        font.pixelSize: 36
                        font.weight: 700
                        color: "white"
                    }
                }
                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "NimbusShell"
                        font.pixelSize: 28
                        font.weight: 600
                        color: root.c.label
                    }
                    Text {
                        text: "Versión " + backend.version + " · " + backend.osName
                        font.pixelSize: 13
                        color: root.c.label2
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: root.c.separator
            }
            GridLayout {
                columns: 2
                columnSpacing: 12
                rowSpacing: 4
                Layout.fillWidth: true
                Text {
                    text: "Núcleo:"
                    font.pixelSize: 13
                    color: root.c.label2
                }
                Text {
                    text: backend.kernel
                    font.pixelSize: 13
                    color: root.c.label
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: "Plasma:"
                    font.pixelSize: 13
                    color: root.c.label2
                }
                Text {
                    text: backend.plasmaVersion
                    font.pixelSize: 13
                    color: root.c.label
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: "Qt:"
                    font.pixelSize: 13
                    color: root.c.label2
                }
                Text {
                    text: backend.qtVersion
                    font.pixelSize: 13
                    color: root.c.label
                }
                Text {
                    text: "KWin:"
                    font.pixelSize: 13
                    color: root.c.label2
                }
                Text {
                    text: backend.kwinVersion
                    font.pixelSize: 13
                    color: root.c.label
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: "CPU:"
                    font.pixelSize: 13
                    color: root.c.label2
                }
                Text {
                    text: backend.cpu
                    font.pixelSize: 13
                    color: root.c.label
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: "RAM:"
                    font.pixelSize: 13
                    color: root.c.label2
                }
                Text {
                    text: backend.ram
                    font.pixelSize: 13
                    color: root.c.label
                }
                Text {
                    text: "GPU:"
                    font.pixelSize: 13
                    color: root.c.label2
                }
                Text {
                    text: backend.gpu
                    font.pixelSize: 13
                    color: root.c.label
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
            Text {
                text: backend.credits
                font.pixelSize: 11
                color: root.c.label2
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            RowLayout {
                spacing: 8
                Button {
                    text: "Guía de usuario"
                    onClicked: backend.openHelp("guide")
                }
                Button {
                    text: "Atajos"
                    onClicked: backend.openHelp("shortcuts")
                }
                Button {
                    text: "Copiar información"
                    highlighted: true
                    onClicked: backend.copyInfo()
                }
            }
        }
    }
}
