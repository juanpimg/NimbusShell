import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation
    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#1e1e2e"
        }
        Text {
            anchors.centerIn: parent
            text: "NimbusOS"
            color: "#ffffff"
            font.pixelSize: 56
            font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 32
            text: "macOS Tahoe 1:1 sobre Plasma"
            color: "#c0c0c0"
            font.pixelSize: 20
        }
    }
}
