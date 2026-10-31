import QtQuick

// LockScreen — raíz del tema de bloqueo Nimbus (F10-T04, Plasma 6.8).
// look-and-feel org.nimbus.desktop, kscreenlockerrc [Greeter] Theme.
// Expone la API mágica que kscreenlocker_greet busca (igual que el tema
// CachyOS-Nord verificado en /usr/share/plasma/look-and-feel): debug,
// notification, clearPassword, notificationRepeated, viewVisible y las
// señales de suspensión. El contenido es NimbusLockUi (componente propio).
Item {
    id: root

    property bool debug: false
    property string notification
    // Propiedades mágicas que kscreenlocker busca.
    property bool viewVisible: false
    property bool suspendToRamSupported: false
    property bool suspendToDiskSupported: false

    signal clearPassword()
    signal notificationRepeated()
    // Señales mágicas que kscreenlocker busca.
    signal suspendToDisk()
    signal suspendToRam()

    LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true
    implicitWidth: 800
    implicitHeight: 600
    // Cualquier tecla muestra la tarjeta; Esc la oculta y limpia.
    Keys.onEscapePressed: {
        if (nimbusUi.uiVisible) {
            nimbusUi.uiVisible = false;
            root.clearPassword();
        }
    }
    Keys.onPressed: (event) => {
        nimbusUi.uiVisible = true;
        event.accepted = false;
    }
    Component.onCompleted: authenticator.startAuthenticating()

    NimbusLockUi {
        id: nimbusUi

        anchors.fill: parent
        onNotificationChanged: {
            if (nimbusUi.notification !== "")
                root.notification = nimbusUi.notification;

        }
    }

    Connections {
        function onClearPassword() {
            nimbusUi.clearPassword();
        }

        target: root
    }

}
