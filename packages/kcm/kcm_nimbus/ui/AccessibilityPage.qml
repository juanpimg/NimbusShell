// F8-T05 — Accesibilidad real: zoom e inversión de KWin, movimiento y
// transparencia reducidos, repetición de teclado y lector Orca. Todo sale
// por kcm (C++) y se aplica con «Aplicar». i18n() extraíble (F11-T05).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCMUtils

KCMUtils.SimpleKCM {
    id: page

    property var kcmRef: (typeof kcm !== "undefined") ? kcm : null

    Kirigami.FormLayout {
        QQC2.Switch {
            Kirigami.FormData.label: i18n("Ver:")
            text: i18n("Ampliar la pantalla con el teclado")
            Accessible.name: i18n("Ampliar la pantalla con la lupa de KWin")
            checked: page.kcmRef ? page.kcmRef.zoomEnabled : false
            onToggled: {
                if (page.kcmRef) {
                    page.kcmRef.zoomEnabled = checked;
                }
            }
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.disabledTextColor
            text: i18n("Activa la lupa con Meta + «+» y Meta + «−».")
        }

        QQC2.Switch {
            Kirigami.FormData.label: i18n("Colores:")
            text: i18n("Invertir los colores de la pantalla")
            Accessible.name: i18n("Invertir los colores de la pantalla")
            checked: page.kcmRef ? page.kcmRef.invertColors : false
            onToggled: {
                if (page.kcmRef) {
                    page.kcmRef.invertColors = checked;
                }
            }
        }

        QQC2.Switch {
            Kirigami.FormData.label: i18n("Movimiento:")
            text: i18n("Reducir las animaciones")
            Accessible.name: i18n("Reducir las animaciones")
            checked: page.kcmRef ? page.kcmRef.reduceMotion : false
            onToggled: {
                if (page.kcmRef) {
                    page.kcmRef.reduceMotion = checked;
                }
            }
        }

        QQC2.Switch {
            Kirigami.FormData.label: i18n("Transparencia:")
            text: i18n("Quitar transparencias y desenfoques")
            Accessible.name: i18n("Quitar transparencias y desenfoques")
            checked: page.kcmRef ? page.kcmRef.reduceTransparency : false
            onToggled: {
                if (page.kcmRef) {
                    page.kcmRef.reduceTransparency = checked;
                }
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Teclado")
        }

        QQC2.Switch {
            Kirigami.FormData.label: i18n("Repetición:")
            text: i18n("Repetir la tecla al mantenerla pulsada")
            Accessible.name: i18n("Repetir la tecla al mantenerla pulsada")
            checked: page.kcmRef ? page.kcmRef.keyboardRepeat : true
            onToggled: {
                if (page.kcmRef) {
                    page.kcmRef.keyboardRepeat = checked;
                }
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Retardo:")
            QQC2.Slider {
                Layout.fillWidth: true
                from: 100
                to: 1000
                stepSize: 50
                enabled: page.kcmRef ? page.kcmRef.keyboardRepeat : true
                value: page.kcmRef ? page.kcmRef.repeatDelay : 500
                Accessible.name: i18n("Milisegundos antes de repetir")
                onMoved: {
                    if (page.kcmRef) {
                        page.kcmRef.repeatDelay = Math.round(value);
                    }
                }
            }
            QQC2.Label {
                text: page.kcmRef ? i18n("%1 ms", page.kcmRef.repeatDelay) : ""
                Layout.minimumWidth: Kirigami.Units.gridUnit * 4
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Velocidad:")
            QQC2.Slider {
                Layout.fillWidth: true
                from: 5
                to: 50
                stepSize: 1
                enabled: page.kcmRef ? page.kcmRef.keyboardRepeat : true
                value: page.kcmRef ? page.kcmRef.repeatRate : 25
                Accessible.name: i18n("Repeticiones por segundo")
                onMoved: {
                    if (page.kcmRef) {
                        page.kcmRef.repeatRate = Math.round(value);
                    }
                }
            }
            QQC2.Label {
                text: page.kcmRef ? i18n("%1/s", page.kcmRef.repeatRate) : ""
                Layout.minimumWidth: Kirigami.Units.gridUnit * 4
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Lector de pantalla")
        }

        QQC2.Switch {
            Kirigami.FormData.label: i18n("Orca:")
            text: i18n("Leer en voz alta lo que hay en pantalla")
            Accessible.name: i18n("Activar el lector de pantalla Orca")
            checked: page.kcmRef ? page.kcmRef.screenReader : false
            onToggled: {
                if (page.kcmRef) {
                    page.kcmRef.screenReader = checked;
                }
            }
        }
        QQC2.Label {
            Layout.fillWidth: true
            visible: page.kcmRef ? !page.kcmRef.orcaInstalled : false
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.neutralTextColor
            text: i18n("Orca no está instalado: el interruptor se guardará, pero no habrá voz hasta instalarlo.")
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.disabledTextColor
            text: i18n("Todo se aplica al pulsar «Aplicar». KWin relee su configuración solo; el resto aplica al reiniciar la sesión.")
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
