// F8-T04 — Atajos reales: modo Cmd (Meta, defecto Nimbus, cero Ctrl nuevos)
// u opt-in Ctrl vía scripts/nimbus-keys, chuleta y salto al editor avanzado.
// Sin atajos CTRL-* nuevos por defecto (R-CTRL). i18n() extraíble (F11-T05).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami

KCMUtils.SimpleKCM {
    id: page

    property var kcmRef: (typeof kcm !== "undefined") ? kcm : null
    // Chuleta central (de scripts/nimbus-keys TABLE): modificador + acción.
    property var cheatsheet: [
        {
            "keys": "⌘Q",
            "what": i18n("Cerrar ventana")
        },
        {
            "keys": "⌘M",
            "what": i18n("Minimizar ventana")
        },
        {
            "keys": "⌘W",
            "what": i18n("Mission Control (Overview)")
        },
        {
            "keys": "⌘E",
            "what": i18n("Exposé del escritorio")
        },
        {
            "keys": "⌘D",
            "what": i18n("Mostrar escritorio")
        },
        {
            "keys": "⌘Espacio",
            "what": i18n("Spotlight (KRunner)")
        },
        {
            "keys": "⌘Tab",
            "what": i18n("Cambiar de aplicación")
        },
        {
            "keys": "⌘Mayús+3",
            "what": i18n("Captura de pantalla")
        }
    ]

    Kirigami.FormLayout {
        // Reset canónico de la sección (F8-T08): arriba para estar visible.
        RowLayout {
            QQC2.Button {
                text: i18n("Restablecer esta sección")
                Accessible.name: i18n("Restablecer esta sección a valores Nimbus")
                onClicked: {
                    if (page.kcmRef)
                        page.kcmRef.resetSection("shortcuts");
                }
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Tecla de comando:")

            QQC2.RadioButton {
                text: i18n("⌘ Cmd (Meta)")
                Accessible.name: i18n("Usar Meta como tecla de comando")
                checked: page.kcmRef ? page.kcmRef.cmdMode : true
                onToggled: {
                    if (page.kcmRef)
                        page.kcmRef.cmdMode = checked;
                }
            }

            QQC2.RadioButton {
                text: i18n("Ctrl")
                Accessible.name: i18n("Usar Control como tecla de comando")
                checked: page.kcmRef ? !page.kcmRef.cmdMode : false
                onToggled: {
                    if (page.kcmRef)
                        page.kcmRef.cmdMode = !checked;
                }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.disabledTextColor
            text: i18n("El modo Cmd no crea atajos Ctrl nuevos. El modo Ctrl es voluntario. Se aplica con «Aplicar» y rige tras reiniciar la sesión.")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Chuleta")
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: Kirigami.Units.smallSpacing

            Repeater {
                model: page.cheatsheet

                delegate: RowLayout {
                    required property var modelData

                    Layout.fillWidth: true

                    QQC2.Label {
                        text: modelData.keys
                        font.bold: true
                        Layout.minimumWidth: Kirigami.Units.gridUnit * 6
                    }

                    QQC2.Label {
                        Layout.fillWidth: true
                        text: modelData.what
                        elide: Text.ElideRight
                    }
                }
            }
        }

        RowLayout {
            QQC2.Button {
                text: i18n("Editor avanzado")
                Accessible.name: i18n("Abrir el editor avanzado de atajos")
                onClicked: {
                    if (page.kcmRef && !page.kcmRef.openKcm("kcm_keys"))
                        page.kcmRef.helperStatus = i18n("No disponible en este sistema.");
                }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            visible: page.kcmRef && page.kcmRef.helperStatus.length > 0
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.neutralTextColor
            text: page.kcmRef ? page.kcmRef.helperStatus : ""
        }
    }
}
