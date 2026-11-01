// NimbusLockUi — contenido del bloqueo Nimbus (F10-T04, look-and-feel
// org.nimbus.desktop). Estilo login macOS: fondo del usuario + velo oscuro,
// reloj grande con fecha, tarjeta glass con avatar circular, nombre,
// contraseña, botones de sesión (suspender/hibernar/cambiar/apagar/
// reiniciar) y pie con teclado/Esc. Sin activos Apple.

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.plasma.private.sessions
import org.kde.plasma.workspace.components as PW
import org.kde.plasma.workspace.keyboardlayout as Keyboards

// Propiedades mágicas del greeter usadas: authenticator, config, wallpaper,
// kscreenlocker_userName, kscreenlocker_userImage.
Item {
    id: nimbusUi

    property bool uiVisible: false
    property string notification: ""
    property string pendingPassword: ""

    function clearPassword() {
        passwordBox.text = "";
        passwordBox.forceActiveFocus();
    }

    function showMessage(msg) {
        if (nimbusUi.notification === "")
            nimbusUi.notification = msg;
        else if (!nimbusUi.notification.includes(msg))
            nimbusUi.notification = nimbusUi.notification + "\n" + msg;
        nimbusUi.uiVisible = true;
    }

    function startLogin() {
        var pw = passwordBox.text;
        loginButton.forceActiveFocus();
        if (authenticator.pamTimeout) {
            nimbusUi.pendingPassword = pw;
            nimbusUi.enabled = false;
        } else {
            authenticator.respond(pw);
        }
    }

    onUiVisibleChanged: {
        if (nimbusUi.uiVisible)
            fadeoutTimer.restart();
        else
            fadeoutTimer.stop();
    }

    SessionManagement {
        id: sessionManagement
    }

    KeyboardIndicator.KeyState {
        id: capsLockState

        key: Qt.Key_CapsLock
    }

    Connections {
        function onFailed(what, auth) {
            if (what != 0)
                return;

            nimbusUi.showMessage("No se ha podido desbloquear");
            nimbusUi.clearPassword();
            authenticator.startAuthenticating();
            notificationTimer.restart();
            rejectAnimation.start();
        }

        function onSucceeded() {
            // Tema basado en contraseña: al autenticar, cerrar el greeter.
            authenticator.stopAuthenticating();
            Qt.quit();
        }

        function onInfoMessageChanged() {
            nimbusUi.showMessage(authenticator.infoMessage);
        }

        function onErrorMessageChanged() {
            nimbusUi.showMessage(authenticator.errorMessage);
        }

        function onPromptChanged() {
            nimbusUi.showMessage(authenticator.prompt);
        }

        target: authenticator
    }

    Connections {
        function onAboutToSuspend() {
            nimbusUi.clearPassword();
        }

        target: sessionManagement
    }

    Connections {
        function onPamTimeoutChanged() {
            if (!authenticator.pamTimeout && nimbusUi.pendingPassword.length > 0) {
                authenticator.respond(nimbusUi.pendingPassword);
                nimbusUi.pendingPassword = "";
                nimbusUi.enabled = true;
            }
        }

        target: authenticator
    }

    // Fondo: wallpaper del usuario + velo oscuro (contraste AA del blanco).
    Image {
        id: wallpaperImage

        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        source: wallpaper
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.45
    }

    // Reloj grande + fecha (siempre visible, como el login macOS).
    NimbusLockClock {
        id: lockClock

        anchors.top: parent.top
        anchors.topMargin: 64
        anchors.horizontalCenter: parent.horizontalCenter
        width: 420
        height: 190
        textColor: "white"
        subColor: "#EBEBF5"
    }

    // Tarjeta glass centrada: avatar + usuario + contraseña + acciones.
    Rectangle {
        id: card

        anchors.centerIn: parent
        width: 360
        height: cardLayout.implicitHeight + 48
        radius: 20
        color: "#2C2C2E"
        opacity: nimbusUi.uiVisible ? 0.82 : 0
        visible: opacity > 0
        border.color: "#EBEBF5"
        border.width: 1

        ColumnLayout {
            id: cardLayout

            anchors.centerIn: parent
            width: parent.width - 48
            spacing: 12

            // Avatar circular: foto del usuario o inicial (arte propio).
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 72
                height: 72
                radius: 36
                color: "#3A3A3C"
                clip: true

                Image {
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: kscreenlocker_userImage !== "" ? "file://" + kscreenlocker_userImage : ""
                    visible: kscreenlocker_userImage !== ""
                }

                Text {
                    anchors.centerIn: parent
                    visible: kscreenlocker_userImage === ""
                    text: kscreenlocker_userName.length > 0 ? kscreenlocker_userName.charAt(0).toUpperCase() : "?"
                    color: "white"
                    font.family: "Inter"
                    font.pixelSize: 28
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: kscreenlocker_userName
                color: "white"
                font.family: "Inter"
                font.pixelSize: 17
                Accessible.name: "Usuario " + kscreenlocker_userName
            }

            PlasmaExtras.PasswordField {
                id: passwordBox

                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 280
                placeholderText: "Contraseña"
                focus: true
                enabled: !authenticator.graceLocked
                cursorVisible: visible
                onAccepted: {
                    if (nimbusUi.uiVisible)
                        nimbusUi.startLogin();
                }
                Accessible.name: "Contraseña"
            }

            PlasmaComponents3.Button {
                id: loginButton

                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 280
                Layout.preferredHeight: 36
                text: "Desbloquear"
                Accessible.name: "Desbloquear"
                onClicked: nimbusUi.startLogin()
            }

            // Mensajes: CapsLock + errores de autenticación (nunca solo color).
            Text {
                id: failLabel

                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: text !== ""
                text: {
                    var parts = [];
                    if (capsLockState.locked)
                        parts.push("Bloq Mayús activado");

                    if (nimbusUi.notification !== "")
                        parts.push(nimbusUi.notification);

                    return parts.join(" • ");
                }
                color: "#FF453A"
                font.family: "Inter"
                font.pixelSize: 13
            }

            // Acciones de sesión (iconos + texto, hit ≥24px; Flow de 2 filas
            // si no caben en una: nunca recorte horizontal).
            Flow {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                spacing: 4

                PlasmaComponents3.ToolButton {
                    text: "Suspender"
                    icon.name: "system-suspend"
                    visible: sessionManagement.canSuspend
                    onClicked: sessionManagement.suspend()
                    Accessible.name: "Suspender"
                }

                PlasmaComponents3.ToolButton {
                    text: "Hibernar"
                    icon.name: "system-suspend-hibernate"
                    visible: sessionManagement.canHibernate
                    onClicked: sessionManagement.hibernate()
                    Accessible.name: "Hibernar"
                }

                PlasmaComponents3.ToolButton {
                    text: "Cambiar"
                    icon.name: "system-switch-user"
                    visible: sessionManagement.canSwitchUser
                    onClicked: sessionManagement.switchUser()
                    Accessible.name: "Cambiar de usuario"
                }

                PlasmaComponents3.ToolButton {
                    text: "Reiniciar"
                    icon.name: "system-reboot"
                    visible: sessionManagement.canReboot
                    onClicked: sessionManagement.requestReboot()
                    Accessible.name: "Reiniciar"
                }

                PlasmaComponents3.ToolButton {
                    text: "Apagar"
                    icon.name: "system-shutdown"
                    visible: sessionManagement.canShutdown
                    onClicked: sessionManagement.requestShutdown()
                    Accessible.name: "Apagar"
                }
            }
        }

        Behavior on opacity {
            OpacityAnimator {
                duration: 250
                easing.type: Easing.InOutQuad
            }
        }
    }

    // Animación de rechazo (desplazamiento horizontal de la tarjeta).
    SequentialAnimation {
        id: rejectAnimation

        NumberAnimation {
            target: card
            property: "x"
            from: card.x - 12
            to: card.x + 12
            duration: 60
        }

        NumberAnimation {
            target: card
            property: "x"
            from: card.x + 12
            to: card.x - 12
            duration: 60
        }

        NumberAnimation {
            target: card
            property: "x"
            from: card.x - 12
            to: card.x
            duration: 60
        }
    }

    // Pie: teclado virtual + layout + pista Esc (sincronizado con SDDM).
    RowLayout {
        id: footer

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 4
        spacing: 4

        PlasmaComponents3.ToolButton {
            text: "Teclado virtual"
            icon.name: Keyboards.KWinVirtualKeyboard.visible ? "input-keyboard-virtual-on" : "input-keyboard-virtual-off"
            onClicked: {
                if (Keyboards.KWinVirtualKeyboard.visible) {
                    Keyboards.KWinVirtualKeyboard.active = false;
                } else {
                    passwordBox.forceActiveFocus();
                    Keyboards.KWinVirtualKeyboard.forceActivate();
                }
            }
            Accessible.name: "Teclado virtual"
        }

        PlasmaComponents3.ToolButton {
            id: keyboardButton

            icon.name: "input-keyboard"
            Accessible.description: "Cambiar disposición del teclado"
            text: keyboardLayoutSwitcher.layoutNames.longName
            onClicked: keyboardLayoutSwitcher.keyboardLayout.switchToNextLayout()
            visible: keyboardLayoutSwitcher.hasMultipleKeyboardLayouts

            PW.KeyboardLayoutSwitcher {
                id: keyboardLayoutSwitcher

                anchors.fill: parent
                acceptedButtons: Qt.NoButton
            }
        }

        Item {
            Layout.fillWidth: true
        }

        Text {
            text: "Pulsa Esc para ocultar • cualquier tecla para mostrar"
            color: "#EBEBF5"
            opacity: 0.6
            font.family: "Inter"
            font.pixelSize: 11
        }
    }

    Timer {
        id: notificationTimer

        interval: 3000
        onTriggered: nimbusUi.notification = ""
    }

    Timer {
        id: fadeoutTimer

        interval: 10000
        onTriggered: {
            if (passwordBox.text.length === 0 && !Keyboards.KWinVirtualKeyboard.visible)
                nimbusUi.uiVisible = false;
        }
    }
}
