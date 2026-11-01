// F8-T07 — Actualizaciones reales: cuenta pendientes con checkupdates
// (sin root; fallback pacman -Qu), programar aviso diario con un timer de
// usuario y enlaces a Discover/copias. Lenguaje llano. i18n() (F11-T05).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCMUtils

KCMUtils.SimpleKCM {
    id: page

    property var kcmRef: (typeof kcm !== "undefined") ? kcm : null
    property string pendingPkg: ""

    // Seam de test: el harness pide la comprobación al abrir la página.
    Component.onCompleted: {
        if (page.kcmRef && page.kcmRef.autoCheckUpdates) {
            page.kcmRef.refreshUpdates();
        }
    }

    Kirigami.FormLayout {
        // Reset canónico de la sección (F8-T08): arriba para estar visible.
        RowLayout {
            QQC2.Button {
                text: i18n("Restablecer esta sección")
                Accessible.name: i18n("Restablecer esta sección a valores Nimbus")
                onClicked: {
                    if (page.kcmRef) {
                        page.kcmRef.resetSection("updates");
                    }
                }
            }
        }
        QQC2.Label {
            Layout.fillWidth: true
            visible: page.kcmRef ? !page.kcmRef.updatesAvailable : false
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.neutralTextColor
            text: i18n("Este equipo no usa paquetes de Arch.")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Estado:")
            visible: page.kcmRef ? page.kcmRef.updatesAvailable : true
            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: page.kcmRef && page.kcmRef.updatesCount > 0
                    ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.positiveTextColor
                text: {
                    if (!page.kcmRef) {
                        return "";
                    }
                    if (page.kcmRef.updatesChecking) {
                        return i18n("Comprobando…");
                    }
                    if (page.kcmRef.updatesCount < 0) {
                        return i18n("Aún sin comprobar.");
                    }
                    if (page.kcmRef.updatesCount === 0) {
                        return i18n("Todo al día. Buen trabajo.");
                    }
                    return i18n("Tienes %1 actualizaciones pendientes.", page.kcmRef.updatesCount);
                }
                Accessible.name: i18n("Estado de las actualizaciones")
            }
            QQC2.Button {
                text: i18n("Comprobar ahora")
                Accessible.name: i18n("Comprobar actualizaciones ahora")
                enabled: page.kcmRef ? !page.kcmRef.updatesChecking : false
                onClicked: {
                    if (page.kcmRef) {
                        page.kcmRef.refreshUpdates();
                    }
                }
            }
        }

        ColumnLayout {
            Kirigami.FormData.label: i18n("Pendientes:")
            visible: page.kcmRef ? page.kcmRef.updatesAvailable && page.kcmRef.updatesCount > 0 : false
            spacing: 0
            Repeater {
                model: page.kcmRef ? page.kcmRef.updatesList : []
                delegate: RowLayout {
                    required property string modelData
                    Layout.fillWidth: true
                    property string pkgName: modelData.split(" ")[0]
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: modelData
                        elide: Text.ElideRight
                        font.family: "monospace"
                    }
                    QQC2.Button {
                        text: i18n("Instalar")
                        Accessible.name: i18n("Instalar %1 (pedirá permiso)", pkgName)
                        enabled: page.kcmRef ? !page.kcmRef.installingUpdate : false
                        onClicked: {
                            page.pendingPkg = pkgName;
                            installDialog.open();
                        }
                    }
                }
            }
            QQC2.Label {
                visible: page.kcmRef ? page.kcmRef.installingUpdate : false
                color: Kirigami.Theme.neutralTextColor
                text: page.kcmRef ? i18n("Instalando %1…", page.kcmRef.installingPackage) : ""
            }
            QQC2.Label {
                Layout.fillWidth: true
                visible: page.kcmRef ? page.kcmRef.installOutput.length > 0 : false
                wrapMode: Text.WordWrap
                color: Kirigami.Theme.disabledTextColor
                text: page.kcmRef ? page.kcmRef.installOutput : ""
            }
            QQC2.Label {
                visible: page.kcmRef ? page.kcmRef.updatesCount > page.kcmRef.updatesList.length : false
                color: Kirigami.Theme.disabledTextColor
                text: page.kcmRef ? i18n("…y %1 más.", page.kcmRef.updatesCount - page.kcmRef.updatesList.length) : ""
            }
        }

        QQC2.Switch {
            Kirigami.FormData.label: i18n("Aviso diario:")
            visible: page.kcmRef ? page.kcmRef.updatesAvailable : true
            text: i18n("Avisar cada día si hay pendientes")
            Accessible.name: i18n("Programar comprobación diaria")
            checked: page.kcmRef ? page.kcmRef.dailyCheck : false
            onToggled: {
                if (page.kcmRef) {
                    page.kcmRef.dailyCheck = checked;
                }
            }
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.disabledTextColor
            text: i18n("Crea un temporizador de usuario (sin root). Se guarda con «Aplicar».")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Instalar y volver atrás")
        }

        RowLayout {
            QQC2.Button {
                text: i18n("Abrir Discover")
                Accessible.name: i18n("Abrir la tienda Discover para instalar")
                enabled: page.kcmRef ? page.kcmRef.discoverInstalled : false
                onClicked: {
                    if (page.kcmRef) {
                        page.kcmRef.openApp("plasma-discover");
                    }
                }
            }
            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Kirigami.Theme.disabledTextColor
                text: page.kcmRef && !page.kcmRef.discoverInstalled
                    ? i18n("Discover no está instalado; actualiza con pacman en un terminal.")
                    : i18n("Instalar y actualizar se hace en Discover.")
            }
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.disabledTextColor
            text: page.kcmRef && page.kcmRef.snapshotsAvailable
                ? i18n("Este equipo guarda copias (snapper): si algo se rompe al actualizar, puedes volver atrás.")
                : i18n("Este equipo no guarda copias automáticas.")
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
        id: installDialog
        title: i18n("Instalar %1", page.pendingPkg)
        standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel
        modal: true
        anchors.centerIn: Overlay.overlay
        contentItem: QQC2.Label {
            wrapMode: Text.WordWrap
            text: i18n("Se instalará %1 con permisos de administrador. ¿Seguir?", page.pendingPkg)
        }
        onAccepted: {
            if (page.kcmRef && page.pendingPkg.length > 0) {
                page.kcmRef.installUpdate(page.pendingPkg);
            }
        }
    }
}
