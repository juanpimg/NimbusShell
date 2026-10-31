// F8-T01 — Apariencia: primera página funcional (control real).
// Lee/escribe kcm.darkMode y kcm.accentColor (kdeglobals, vía C++).
import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCMUtils

KCMUtils.SimpleKCM {
    id: page

    // kcm lo inyecta el cargador; guardia para qmllint/tests sin cargador.
    property var kcmRef: (typeof kcm !== "undefined") ? kcm : null

    Kirigami.FormLayout {
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
                    if (checked && page.kcmRef) {
                        page.kcmRef.darkMode = false;
                    }
                }
            }
            QQC2.RadioButton {
                text: i18n("Oscuro")
                Accessible.name: i18n("Tema oscuro")
                checked: page.kcmRef ? page.kcmRef.darkMode : true
                onToggled: {
                    if (checked && page.kcmRef) {
                        page.kcmRef.darkMode = true;
                    }
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

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.disabledTextColor
            // Contratos Tahoe §2.1: #007AFF claro / #0A84FF oscuro [HIG].
            text: i18n("El tema se aplica al pulsar «Aplicar». El fondo y el Dock llegan en la página completa (F8-T02).")
        }
    }

    ColorDialog {
        id: accentDialog
        title: i18n("Color de acento")
        selectedColor: page.kcmRef ? page.kcmRef.accentColor : "#0A84FF"
        onAccepted: {
            if (page.kcmRef) {
                page.kcmRef.accentColor = selectedColor.toString();
            }
        }
    }
}
