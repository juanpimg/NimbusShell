// F8-T02 — Apariencia real: tema, acento, fondo, Dock Krema, barra,
// animaciones + mini previsualización. Todo sale por kcm (C++) y se aplica
// con «Aplicar». i18n() extraíble (F11-T05).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami

KCMUtils.SimpleKCM {
    id: page

    // kcm lo inyecta el cargador; guardia para qmllint/tests sin cargador.
    property var kcmRef: (typeof kcm !== "undefined") ? kcm : null

    Kirigami.FormLayout {
        // Reset canónico de la sección (F8-T08): arriba para estar visible.
        RowLayout {
            QQC2.Button {
                text: i18n("Restablecer esta sección")
                Accessible.name: i18n("Restablecer esta sección a valores Nimbus")
                onClicked: {
                    if (page.kcmRef)
                        page.kcmRef.resetSection("appearance");
                }
            }
        }

        // Dos radios en vez de ComboBox: el checked deriva de kcm desde el
        // inicio (el ComboBox emite activated al asignar el modelo y
        // corrompe el estado antes de que el usuario toque nada).
        RowLayout {
            Kirigami.FormData.label: i18n("Apariencia:")

            QQC2.RadioButton {
                text: i18n("Claro")
                Accessible.name: i18n("Tema claro")
                checked: page.kcmRef ? !page.kcmRef.darkMode : false
                onToggled: {
                    if (page.kcmRef)
                        page.kcmRef.darkMode = !checked;
                }
            }

            QQC2.RadioButton {
                text: i18n("Oscuro")
                Accessible.name: i18n("Tema oscuro")
                checked: page.kcmRef ? page.kcmRef.darkMode : true
                onToggled: {
                    if (page.kcmRef)
                        page.kcmRef.darkMode = checked;
                }
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Color de acento:")

            Rectangle {
                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                implicitHeight: Kirigami.Units.iconSizes.smallMedium
                radius: width / 2
                // Dato del usuario, no token: refleja el acento elegido.
                color: page.kcmRef ? page.kcmRef.accentColor : "transparent"
                border.color: Kirigami.Theme.disabledTextColor
            }

            QQC2.Button {
                text: page.kcmRef ? page.kcmRef.accentColor : ""
                Accessible.name: i18n("Elegir color de acento")
                onClicked: accentDialog.open()
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Fondo:")

            QQC2.Label {
                Layout.fillWidth: true
                elide: Text.ElideMiddle
                color: Kirigami.Theme.disabledTextColor
                text: page.kcmRef && page.kcmRef.wallpaperPath.length > 0 ? page.kcmRef.wallpaperPath : i18n("Automático según el tema")
                Accessible.name: i18n("Fondo actual")
            }

            QQC2.Button {
                text: i18n("Elegir…")
                Accessible.name: i18n("Elegir imagen de fondo")
                onClicked: wallpaperDialog.open()
            }

            QQC2.Button {
                text: i18n("Automático")
                Accessible.name: i18n("Volver al fondo automático")
                enabled: page.kcmRef && page.kcmRef.wallpaperPath.length > 0
                onClicked: {
                    if (page.kcmRef)
                        page.kcmRef.wallpaperPath = "";
                }
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Dock")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Tamaño de icono:")

            QQC2.Slider {
                Layout.fillWidth: true
                from: 24
                to: 96
                stepSize: 1
                value: page.kcmRef ? page.kcmRef.dockIconSize : 48
                Accessible.name: i18n("Tamaño de icono del Dock")
                onMoved: {
                    if (page.kcmRef)
                        page.kcmRef.dockIconSize = Math.round(value);
                }
            }

            QQC2.Label {
                text: page.kcmRef ? page.kcmRef.dockIconSize + " px" : ""
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Ampliación al pasar:")

            QQC2.Slider {
                Layout.fillWidth: true
                from: 1
                to: 2
                stepSize: 0.1
                value: page.kcmRef ? page.kcmRef.dockZoomFactor : 1.6
                Accessible.name: i18n("Ampliación de iconos al pasar el ratón")
                onMoved: {
                    if (page.kcmRef)
                        page.kcmRef.dockZoomFactor = value;
                }
            }

            QQC2.Label {
                text: page.kcmRef ? Number(page.kcmRef.dockZoomFactor).toFixed(1) + "×" : ""
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            }
        }

        QQC2.Switch {
            Kirigami.FormData.label: i18n("Ocultar solo:")
            text: i18n("Ocultar el Dock cuando no se usa")
            Accessible.name: i18n("Ocultar automáticamente el Dock")
            checked: page.kcmRef ? page.kcmRef.dockAutohide : false
            onToggled: {
                if (page.kcmRef)
                    page.kcmRef.dockAutohide = checked;
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Barra y animaciones")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Altura de la barra:")

            QQC2.Slider {
                Layout.fillWidth: true
                from: 16
                to: 64
                stepSize: 1
                value: page.kcmRef ? page.kcmRef.barHeight : 24
                Accessible.name: i18n("Altura de la barra superior")
                onMoved: {
                    if (page.kcmRef)
                        page.kcmRef.barHeight = Math.round(value);
                }
            }

            QQC2.Label {
                text: page.kcmRef ? page.kcmRef.barHeight + " px" : ""
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Velocidad de animación:")

            QQC2.Slider {
                Layout.fillWidth: true
                from: 0
                to: 3
                stepSize: 1
                snapMode: QQC2.Slider.SnapAlways
                value: page.kcmRef ? page.kcmRef.animationSpeed : 3
                Accessible.name: i18n("Velocidad de las animaciones")
                onMoved: {
                    if (page.kcmRef)
                        page.kcmRef.animationSpeed = Math.round(value);
                }
            }

            QQC2.Label {
                text: page.kcmRef ? i18n("%1 de 3", page.kcmRef.animationSpeed) : ""
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            }
        }

        // Mini previsualización: barra + Dock con el acento elegido.
        ColumnLayout {
            Kirigami.FormData.label: i18n("Vista previa:")
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.max(16, Math.min(64, page.kcmRef ? page.kcmRef.barHeight : 24))
                radius: Kirigami.Units.smallSpacing
                color: Kirigami.Theme.alternateBackgroundColor
                border.color: Kirigami.Theme.disabledTextColor

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        text: "Nimbus"
                        font.bold: true
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                        implicitHeight: Kirigami.Units.iconSizes.smallMedium
                        radius: width / 2
                        color: page.kcmRef ? page.kcmRef.accentColor : "transparent"
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: Kirigami.Units.largeSpacing
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: 5

                    delegate: Rectangle {
                        required property int index

                        implicitWidth: (page.kcmRef ? page.kcmRef.dockIconSize : 48) * 0.5 * (index === 2 && page.kcmRef ? page.kcmRef.dockZoomFactor : 1)
                        implicitHeight: implicitWidth
                        radius: Kirigami.Units.smallSpacing
                        color: index === 2 && page.kcmRef ? page.kcmRef.accentColor : Kirigami.Theme.alternateBackgroundColor
                        border.color: Kirigami.Theme.disabledTextColor
                    }
                }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.disabledTextColor
            // Contratos Tahoe §2.1: #007AFF claro / #0A84FF oscuro [HIG].
            text: i18n("Todo se aplica al pulsar «Aplicar». La barra y el Dock nuevos aplican al reiniciar la sesión; «Predeterminados» recupera los valores Nimbus.")
        }

        QQC2.Label {
            Layout.fillWidth: true
            visible: page.kcmRef && page.kcmRef.helperStatus.length > 0
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.neutralTextColor
            text: page.kcmRef ? page.kcmRef.helperStatus : ""
        }
    }

    ColorDialog {
        id: accentDialog

        title: i18n("Color de acento")
        selectedColor: page.kcmRef ? page.kcmRef.accentColor : "#0A84FF"
        onAccepted: {
            if (page.kcmRef)
                page.kcmRef.accentColor = selectedColor.toString();
        }
    }

    FileDialog {
        id: wallpaperDialog

        title: i18n("Elegir fondo")
        fileMode: FileDialog.OpenFile
        nameFilters: [i18n("Imágenes (*.jpg *.jpeg *.png *.webp)")]
        onAccepted: {
            if (page.kcmRef)
                page.kcmRef.wallpaperPath = String(selectedFile).replace(/^file:\/\//, "");
        }
    }
}
