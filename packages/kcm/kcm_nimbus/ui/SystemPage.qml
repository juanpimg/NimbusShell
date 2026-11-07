// F8-T06 — Sistema real: usuarios (AccountsService o /etc/passwd, sin
// contraseñas), equipo, zona horaria, hora automática, idioma y energía.
// Lo que exige administrador solo se muestra (con salto al KCM que pide
// permiso). Sin root. i18n() extraíble (F11-T05).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami

KCMUtils.SimpleKCM {
    id: page

    property var kcmRef: (typeof kcm !== "undefined") ? kcm : null

    Kirigami.FormLayout {
        // Reset canónico de la sección (F8-T08): arriba para estar visible.
        RowLayout {
            QQC2.Button {
                text: i18n("Restablecer esta sección")
                Accessible.name: i18n("Restablecer esta sección a valores Nimbus")
                onClicked: {
                    if (page.kcmRef)
                        page.kcmRef.resetSection("system");
                }
            }
        }

        ColumnLayout {
            Kirigami.FormData.label: i18n("Personas:")
            spacing: 0

            Repeater {
                model: page.kcmRef ? page.kcmRef.userList : []

                delegate: RowLayout {
                    required property string modelData
                    property var parts: modelData.split("|")

                    Layout.fillWidth: true

                    Kirigami.Icon {
                        source: "user-identity"
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                        implicitHeight: Kirigami.Units.iconSizes.smallMedium
                    }

                    QQC2.Label {
                        Layout.fillWidth: true
                        text: parts.length > 1 && parts[1].length > 0 ? i18n("%1 (%2)", parts[0], parts[1]) : (parts.length > 0 ? parts[0] : "")
                        elide: Text.ElideRight
                        font.bold: parts.length > 2 && parts[2] === "1"
                    }

                    QQC2.Label {
                        visible: parts.length > 2 && parts[2] === "1"
                        text: i18n("Eres tú")
                        color: Kirigami.Theme.disabledTextColor
                    }
                }
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Equipo:")

            QQC2.Label {
                Layout.fillWidth: true
                text: page.kcmRef ? page.kcmRef.hostName : ""
                elide: Text.ElideRight
                Accessible.name: i18n("Nombre del equipo")
            }

            QQC2.Button {
                text: i18n("Cambiar…")
                Accessible.name: i18n("Cambiar el nombre del equipo (pide permiso)")
                onClicked: hostnameDialog.open()
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.disabledTextColor
            text: i18n("Cambiar el nombre o añadir personas necesita permiso de administrador.")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Fecha y hora")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Zona:")

            QQC2.Label {
                Layout.fillWidth: true
                text: page.kcmRef ? page.kcmRef.timeZone : ""
                elide: Text.ElideRight
                Accessible.name: i18n("Zona horaria")
            }
        }

        QQC2.Switch {
            Kirigami.FormData.label: i18n("Automática:")
            text: i18n("Poner la hora por internet")
            Accessible.name: i18n("Sincronizar la hora por internet")
            checked: page.kcmRef ? page.kcmRef.ntpEnabled : false
            onToggled: {
                if (page.kcmRef)
                    page.kcmRef.ntpEnabled = checked;
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Idioma y energía")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Idioma:")

            QQC2.Label {
                Layout.fillWidth: true
                text: page.kcmRef ? page.kcmRef.systemLocale : ""
                elide: Text.ElideRight
                Accessible.name: i18n("Idioma del sistema")
            }

            QQC2.Button {
                text: i18n("Cambiar…")
                Accessible.name: i18n("Cambiar el idioma del sistema (pide permiso)")
                onClicked: localeDialog.open()
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Energía:")

            Repeater {
                model: page.kcmRef ? page.kcmRef.energyProfiles : []

                delegate: QQC2.RadioButton {
                    required property string modelData

                    text: modelData === "performance" ? i18n("Máximo") : modelData === "power-saver" ? i18n("Ahorro") : i18n("Equilibrado")
                    Accessible.name: i18n("Perfil de energía %1", text)
                    checked: page.kcmRef ? page.kcmRef.energyProfile === modelData : false
                    onToggled: {
                        if (checked && page.kcmRef)
                            page.kcmRef.energyProfile = modelData;
                    }
                }
            }

            QQC2.Label {
                visible: page.kcmRef ? page.kcmRef.energyProfiles.length === 0 : false
                color: Kirigami.Theme.disabledTextColor
                text: i18n("Sin perfiles de energía en este equipo.")
            }
        }

        RowLayout {
            QQC2.Button {
                text: i18n("Usuarios y fecha avanzados")
                Accessible.name: i18n("Abrir los ajustes originales de usuarios y fecha")
                onClicked: {
                    if (page.kcmRef && !page.kcmRef.openKcm("kcm_users"))
                        page.kcmRef.helperStatus = i18n("No disponible en este sistema.");
                }
            }

            QQC2.Button {
                text: i18n("Idioma avanzado")
                Accessible.name: i18n("Abrir los ajustes originales de idioma")
                onClicked: {
                    if (page.kcmRef && !page.kcmRef.openKcm("kcm_regionandlang"))
                        page.kcmRef.helperStatus = i18n("No disponible en este sistema.");
                }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.disabledTextColor
            text: i18n("Los cambios de energía aplican al momento. Lo demás lo guarda su propio ajuste (puede pedir tu contraseña).")
        }

        QQC2.Label {
            Layout.fillWidth: true
            visible: page.kcmRef && page.kcmRef.helperStatus.length > 0
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.neutralTextColor
            text: page.kcmRef ? page.kcmRef.helperStatus : ""
        }
    }

    QQC2.Dialog {
        id: hostnameDialog

        title: i18n("Nombre del equipo")
        standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel
        modal: true
        anchors.centerIn: Overlay.overlay
        onAccepted: {
            if (page.kcmRef)
                page.kcmRef.trySetHostName(hostnameField.text);
        }

        contentItem: QQC2.TextField {
            id: hostnameField

            placeholderText: i18n("p. ej. mi-portatil")
            Accessible.name: i18n("Nuevo nombre del equipo")
            Component.onCompleted: {
                hostnameField.text = page.kcmRef ? page.kcmRef.hostName : "";
            }
        }
    }

    QQC2.Dialog {
        id: localeDialog

        title: i18n("Idioma del sistema")
        standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel
        modal: true
        anchors.centerIn: Overlay.overlay
        onAccepted: {
            if (page.kcmRef)
                page.kcmRef.trySetLocale(localeField.text);
        }

        contentItem: QQC2.TextField {
            id: localeField

            placeholderText: i18n("p. ej. es_ES.UTF-8")
            Accessible.name: i18n("Nuevo idioma del sistema")
        }
    }
}
