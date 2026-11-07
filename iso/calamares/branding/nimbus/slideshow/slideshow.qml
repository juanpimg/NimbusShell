import QtQuick 2.15
import calamares.slideshow 1.0

Presentation {
    id: presentation

    // Diapositiva 1: Bienvenida e identidad NimbusOS
    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#161b26"

            Column {
                anchors.centerIn: parent
                spacing: 16
                width: parent.width - 96

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "NimbusOS"
                    color: "#ffffff"
                    font.family: "Inter"
                    font.pixelSize: 42
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "La experiencia macOS Tahoe 1:1 sobre Arch Linux y Plasma 6"
                    color: "#7cc4ff"
                    font.family: "Inter"
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Diseño elegante, máxima fluidez y control total sobre tu sistema operativo."
                    color: "#9fb2cc"
                    font.family: "Inter"
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                }
            }
        }
    }

    // Diapositiva 2: Ventanas, Semáforos y Spotlight
    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#161b26"

            Column {
                anchors.centerIn: parent
                spacing: 16
                width: parent.width - 96

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Ventanas y Navegación Tahoe"
                    color: "#ffffff"
                    font.family: "Inter"
                    font.pixelSize: 32
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Semáforos nativos a la izquierda · Spaces · Mission Control"
                    color: "#7cc4ff"
                    font.family: "Inter"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Encuentra cualquier aplicación, archivo o ajuste al instante pulsando Cmd + Espacio con Spotlight."
                    color: "#9fb2cc"
                    font.family: "Inter"
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                }
            }
        }
    }

    // Diapositiva 3: Dock y Barra Superior
    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#161b26"

            Column {
                anchors.centerIn: parent
                spacing: 16
                width: parent.width - 96

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Dock y Barra Superior Integrada"
                    color: "#ffffff"
                    font.family: "Inter"
                    font.pixelSize: 32
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Menú global · Centro de Control · Widgets de tiempo y reloj"
                    color: "#7cc4ff"
                    font.family: "Inter"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Efecto cristal translúcido genuino (Glass), animaciones fluidas y accesos directos unificados."
                    color: "#9fb2cc"
                    font.family: "Inter"
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                }
            }
        }
    }

    // Diapositiva 4: Seguridad y Fiabilidad
    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#161b26"

            Column {
                anchors.centerIn: parent
                spacing: 16
                width: parent.width - 96

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Seguridad y Tranquilidad Total"
                    color: "#ffffff"
                    font.family: "Inter"
                    font.pixelSize: 32
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Instantáneas automáticas Btrfs con retorno seguro · Cero telemetría"
                    color: "#7cc4ff"
                    font.family: "Inter"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Si una actualización falla, vuelve al estado anterior con un solo clic o desde el menú de arranque."
                    color: "#9fb2cc"
                    font.family: "Inter"
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                }
            }
        }
    }
}
