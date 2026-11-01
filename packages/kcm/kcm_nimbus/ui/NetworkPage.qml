// F8-T03 — Red real: wifi (estado, escaneo, conexión con contraseña en
// memoria, jamás guardada), Bluetooth (encendido + vinculados) e impresoras.
// Sin root. i18n() extraíble (F11-T05).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCMUtils

KCMUtils.SimpleKCM {
    id: page

    property var kcmRef: (typeof kcm !== "undefined") ? kcm : null
    property string pendingSsid: ""

    function signalIcon(level) {
        const v = parseInt(level, 10);
        if (v >= 75) {
            return "network-wireless-signal-excellent";
        }
        if (v >= 50) {
            return "network-wireless-signal-good";
        }
        if (v >= 25) {
            return "network-wireless-signal-weak";
        }
        return "network-wireless-signal-none";
    }

    Kirigami.FormLayout {
        // Reset canónico de la sección (F8-T08): arriba para estar visible.
        RowLayout {
            QQC2.Button {
                text: i18n("Restablecer esta sección")
                Accessible.name: i18n("Restablecer esta sección a valores Nimbus")
                onClicked: {
                    if (page.kcmRef) {
                        page.kcmRef.resetSection("network");
                    }
                }
            }
        }
        QQC2.Label {
            Layout.fillWidth: true
            visible: page.kcmRef ? !page.kcmRef.wifiAvailable : false
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.neutralTextColor
            text: i18n("Este equipo no tiene wifi.")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Wifi:")
            visible: page.kcmRef ? page.kcmRef.wifiAvailable : true
            QQC2.Switch {
                text: page.kcmRef && page.kcmRef.wifiSsid.length > 0
                    ? i18n("Conectado a %1", page.kcmRef.wifiSsid) : i18n("Wifi")
                Accessible.name: i18n("Activar o apagar el wifi")
                checked: page.kcmRef ? page.kcmRef.wifiEnabled : false
                onToggled: {
                    if (page.kcmRef) {
                        page.kcmRef.wifiEnabled = checked;
                    }
                }
            }
            QQC2.Button {
                text: page.kcmRef && page.kcmRef.wifiScanning ? i18n("Buscando…") : i18n("Buscar redes")
                Accessible.name: i18n("Buscar redes wifi")
                enabled: page.kcmRef ? page.kcmRef.wifiEnabled && !page.kcmRef.wifiScanning : false
                onClicked: {
                    if (page.kcmRef) {
                        page.kcmRef.refreshWifi();
                    }
                }
            }
        }

        ColumnLayout {
            Kirigami.FormData.label: i18n("Redes:")
            visible: page.kcmRef ? page.kcmRef.wifiAvailable : true
            spacing: 0
            Repeater {
                model: page.kcmRef ? page.kcmRef.wifiNetworks : []
                delegate: QQC2.ItemDelegate {
                    required property string modelData
                    Layout.fillWidth: true
                    property var parts: modelData.split("|")
                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        Kirigami.Icon {
                            source: page.signalIcon(parts.length > 1 ? parts[1] : "0")
                            implicitWidth: Kirigami.Units.iconSizes.smallMedium
                            implicitHeight: Kirigami.Units.iconSizes.smallMedium
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: parts.length > 0 ? parts[0] : ""
                            elide: Text.ElideRight
                            font.bold: parts.length > 3 && parts[3] === "1"
                        }
                        QQC2.Label {
                            visible: parts.length > 2 && parts[2].length > 0 && parts[2] !== "--"
                            text: "🔒"
                            Accessible.name: i18n("Red protegida")
                        }
                    }
                    Accessible.name: parts.length > 0 ? i18n("Conectar a %1", parts[0]) : ""
                    onClicked: {
                        if (parts.length > 0) {
                            page.pendingSsid = parts[0];
                            if (parts.length > 3 && parts[3] === "1") {
                                return;
                            }
                            passwordDialog.open();
                        }
                    }
                }
            }
            QQC2.Label {
                visible: page.kcmRef ? page.kcmRef.wifiNetworks.length === 0 && !page.kcmRef.wifiScanning : false
                color: Kirigami.Theme.disabledTextColor
                text: i18n("Sin redes a la vista. Pulsa «Buscar redes».")
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Bluetooth")
        }

        QQC2.Label {
            Layout.fillWidth: true
            visible: page.kcmRef ? !page.kcmRef.bluetoothAvailable : false
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.neutralTextColor
            text: i18n("Este equipo no tiene Bluetooth.")
        }
        QQC2.Switch {
            Kirigami.FormData.label: i18n("Bluetooth:")
            visible: page.kcmRef ? page.kcmRef.bluetoothAvailable : true
            text: i18n("Bluetooth")
            Accessible.name: i18n("Activar o apagar el Bluetooth")
            checked: page.kcmRef ? page.kcmRef.bluetoothPowered : false
            onToggled: {
                if (page.kcmRef) {
                    page.kcmRef.bluetoothPowered = checked;
                }
            }
        }
        ColumnLayout {
            Kirigami.FormData.label: i18n("Aparatos:")
            visible: page.kcmRef ? page.kcmRef.bluetoothAvailable : true
            spacing: 0
            Repeater {
                model: page.kcmRef ? page.kcmRef.bluetoothDevices : []
                delegate: RowLayout {
                    required property string modelData
                    Layout.fillWidth: true
                    // Modelo "nombre|mac|conectado|vinculado".
                    property var parts: modelData.split("|")
                    property string devMac: parts.length > 1 ? parts[1] : ""
                    property bool devConnected: parts.length > 2 && parts[2] === "1"
                    property bool devPaired: parts.length <= 3 || parts[3] === "1"
                    Kirigami.Icon {
                        source: "preferences-system-bluetooth"
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                        implicitHeight: Kirigami.Units.iconSizes.smallMedium
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: parts.length > 0 ? parts[0] : ""
                        elide: Text.ElideRight
                        color: devConnected ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                    }
                    QQC2.Button {
                        visible: !devPaired
                        text: i18n("Vincular")
                        Accessible.name: parts.length > 0 ? i18n("Vincular %1", parts[0]) : ""
                        onClicked: {
                            if (page.kcmRef) {
                                page.kcmRef.pairBluetooth(devMac);
                            }
                        }
                    }
                    QQC2.Button {
                        visible: devPaired && !devConnected
                        text: i18n("Conectar")
                        Accessible.name: parts.length > 0 ? i18n("Conectar %1", parts[0]) : ""
                        onClicked: {
                            if (page.kcmRef) {
                                page.kcmRef.connectBluetooth(devMac);
                            }
                        }
                    }
                    QQC2.Button {
                        visible: devConnected
                        text: i18n("Desconectar")
                        Accessible.name: parts.length > 0 ? i18n("Desconectar %1", parts[0]) : ""
                        onClicked: {
                            if (page.kcmRef) {
                                page.kcmRef.disconnectBluetooth(devMac);
                            }
                        }
                    }
                }
            }
            QQC2.Label {
                visible: page.kcmRef ? page.kcmRef.bluetoothDevices.length === 0 && !page.kcmRef.bluetoothScanning : false
                color: Kirigami.Theme.disabledTextColor
                text: i18n("Sin aparatos a la vista. Pulsa «Buscar aparatos».")
            }
            RowLayout {
                QQC2.Button {
                    text: page.kcmRef && page.kcmRef.bluetoothScanning ? i18n("Buscando…") : i18n("Buscar aparatos")
                    Accessible.name: i18n("Buscar aparatos Bluetooth cercanos")
                    enabled: page.kcmRef ? page.kcmRef.bluetoothPowered && !page.kcmRef.bluetoothScanning : false
                    onClicked: {
                        if (page.kcmRef) {
                            page.kcmRef.scanBluetooth();
                        }
                    }
                }
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Impresoras")
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.disabledTextColor
            text: page.kcmRef && !page.kcmRef.printingAvailable
                ? i18n("Sin soporte de impresión en este equipo (falta CUPS).")
                : (page.kcmRef && page.kcmRef.printerInfo.length > 0
                    ? page.kcmRef.printerInfo : i18n("Sin impresoras configuradas."))
        }
        ColumnLayout {
            Kirigami.FormData.label: i18n("Probar:")
            visible: page.kcmRef ? page.kcmRef.printingAvailable && page.kcmRef.printerNames.length > 0 : false
            spacing: 0
            Repeater {
                model: page.kcmRef ? page.kcmRef.printerNames : []
                delegate: RowLayout {
                    required property string modelData
                    Layout.fillWidth: true
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: modelData
                        elide: Text.ElideRight
                    }
                    QQC2.Button {
                        text: i18n("Página de prueba")
                        Accessible.name: i18n("Imprimir página de prueba en %1", modelData)
                        onClicked: {
                            if (page.kcmRef) {
                                page.kcmRef.printTestPage(modelData);
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            QQC2.Button {
                text: i18n("Ajustes de red avanzados")
                Accessible.name: i18n("Abrir los ajustes de red originales")
                onClicked: {
                    if (page.kcmRef && !page.kcmRef.openKcm("kcm_networkmanagement")) {
                        page.kcmRef.helperStatus = i18n("No disponible en este sistema.");
                    }
                }
            }
            QQC2.Button {
                text: i18n("Ajustes de Bluetooth avanzados")
                Accessible.name: i18n("Abrir los ajustes de Bluetooth originales")
                onClicked: {
                    if (page.kcmRef && !page.kcmRef.openKcm("kcm_bluetooth")) {
                        page.kcmRef.helperStatus = i18n("No disponible en este sistema.");
                    }
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

    QQC2.Dialog {
        id: passwordDialog
        title: i18n("Contraseña de %1", page.pendingSsid)
        standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel
        modal: true
        anchors.centerIn: Overlay.overlay
        contentItem: QQC2.TextField {
            id: passwordField
            echoMode: TextInput.Password
            placeholderText: i18n("Contraseña del wifi")
            Accessible.name: i18n("Contraseña del wifi (no se guarda)")
        }
        onAccepted: {
            if (page.kcmRef) {
                page.kcmRef.connectWifi(page.pendingSsid, passwordField.text);
            }
            passwordField.text = "";
        }
        onRejected: {
            passwordField.text = "";
        }
    }
}
