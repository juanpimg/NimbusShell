// Bar.qml — barra superior Nimbus 24pt (F3-T03, R-TOPBAR-LAYER).
// Contrato §3 [HIG]: menu bar 24pt, extras 22pt, fuente ~13pt [INFERIDO].
// Layer-shell: top, anclas Left/Top/Right, exclusiveZone 24,
// scope "nimbus-bar", sin teclado, capa Top, sin decoración.
// Tokens vía singleton NimbusTokens (copia md5-idéntica de
// packages/themes/nimbus-tokens/NimbusTokens.qml; sin valores duplicados).
import QtQuick
import QtQuick.Window
// Alias obligatorio: sin `as`, `Window` colisiona con el tipo no-creable
// org.kde.layershell/Window y la creación falla ("Type cannot be created").
import org.kde.layershell as LayerShellQt
import "."

Window {
    id: root
    width: Screen.width
    height: 24
    visible: true
    visibility: Window.Windowed
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    title: "nimbus-bar"

    LayerShellQt.Window.anchors: LayerShellQt.Window.AnchorTop | LayerShellQt.Window.AnchorLeft | LayerShellQt.Window.AnchorRight
    LayerShellQt.Window.exclusionZone: 24
    LayerShellQt.Window.layer: LayerShellQt.Window.LayerTop
    LayerShellQt.Window.keyboardInteractivity: LayerShellQt.Window.KeyboardInteractivityNone
    LayerShellQt.Window.scope: "nimbus-bar"
    LayerShellQt.Window.activateOnShow: false

    // Fondo glass oscuro. Alfa provisional [INFERIDO]: medir en VM (A1/A4).
    Rectangle {
        id: bg
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
    }
    // Hairline inferior 1px (contrato §2.1 separator dark) [HIG].
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Qt.rgba(0.22, 0.22, 0.23, 0.6)
    }

    Row {
        id: leftBox
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        // Logo "N" propio (arte Nimbus, sin activos Apple).
        // F3-T04: clic abre/cierra el menú Apple.
        Rectangle {
            id: logo
            width: 16
            height: 16
            radius: 4
            anchors.verticalCenter: parent.verticalCenter
            color: NimbusTokens.colors(NimbusTokens.dark).accent
            objectName: "appleLogo"
            Text {
                anchors.centerIn: parent
                text: "N"
                font.family: NimbusTokens.fontFamily
                font.pixelSize: 11
                font.weight: 700
                color: "white"
            }
            MouseArea {
                anchors.fill: parent
                onClicked: appleMenu.toggle()
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Nimbus"
            font.family: NimbusTokens.fontFamily
            font.pixelSize: NimbusTokens.type.t13b.size
            font.weight: NimbusTokens.type.t13b.weight
            color: NimbusTokens.colors(NimbusTokens.dark).label
        }
    }

    // F3-T04: menú Apple (popup layer-shell propio en Menu.qml).
    // demoMenu lo abre al arrancar (flag --demo-menu, solo UI nested).
    Menu {
        id: appleMenu
        demo: demoMenu
    }
    Component.onCompleted: if (demoMenu)
        appleMenu.open()

    Row {
        id: rightBox
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12
        // Placeholders extras 22pt (menús reales en F3-T04/T05).
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Wi-Fi"
            font.family: NimbusTokens.fontFamily
            font.pixelSize: NimbusTokens.type.t12.size
            color: NimbusTokens.colors(NimbusTokens.dark).label
            Accessible.name: "Wi-Fi (placeholder)"
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "BT"
            font.family: NimbusTokens.fontFamily
            font.pixelSize: NimbusTokens.type.t12.size
            color: NimbusTokens.colors(NimbusTokens.dark).label
            Accessible.name: "Bluetooth (placeholder)"
        }
        // Batería dibujada (sin iconos externos).
        Item {
            width: 26
            height: 12
            anchors.verticalCenter: parent.verticalCenter
            Accessible.name: "Batería (placeholder)"
            Rectangle {
                anchors.fill: parent
                radius: 3
                color: "transparent"
                border.color: NimbusTokens.colors(NimbusTokens.dark).label
                border.width: 1
                opacity: 0.6
            }
            Rectangle {
                x: 2
                y: 2
                width: 18
                height: 8
                radius: 1.5
                color: NimbusTokens.colors(NimbusTokens.dark).label
            }
        }
        Text {
            id: clock
            anchors.verticalCenter: parent.verticalCenter
            font.family: NimbusTokens.fontFamily
            font.pixelSize: NimbusTokens.type.t13.size
            color: NimbusTokens.colors(NimbusTokens.dark).label
            Accessible.name: "Reloj"
            Timer {
                interval: 1000
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: clock.text = Qt.formatTime(new Date(), "HH:mm")
            }
        }
    }
}
