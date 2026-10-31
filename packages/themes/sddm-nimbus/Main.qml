import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SddmComponents 2.0
import "components"

// Main.qml — greeter SDDM Nimbus (F2-T02). Layout centrado estilo login macOS:
// fondo NPS a pantalla completa, reloj arriba, tarjeta glass centrada con
// avatar+usuario, contraseña, selector de sesión/teclado y apagar/reiniciar.
// Tokens: NimbusTokens (copia md5-idéntica de packages/themes/nimbus-tokens).
Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "black"

    // Fondo propio NPS (R-APPLE). `config.background` = Background.jpg.
    Image {
        id: bg
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: config.background
        asynchronous: true
    }
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.25
    }

    // Reloj superior (solo visual, como el login macOS).
    LoginClock {
        anchors.top: parent.top
        anchors.topMargin: 64
        anchors.horizontalCenter: parent.horizontalCenter
        clock24h: config.clock24h === "false" ? false : true
        fontFamily: NimbusTokens.fontFamily
        textColor: NimbusTokens.colors(true).label
    }

    // Tarjeta glass centrada.
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 360
        height: loginLayout.implicitHeight + 48
        radius: NimbusTokens.radii.rLg
        color: NimbusTokens.colors(true).bgElevated
        opacity: 0.78
        border.color: "#EBEBF5"
        border.width: 1

        ColumnLayout {
            id: loginLayout
            anchors.centerIn: parent
            width: parent.width - 48
            spacing: 12

            // Avatar + nombre del usuario actual.
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 72
                height: 72
                radius: 36
                color: "#3A3A3C"
                Text {
                    anchors.centerIn: parent
                    text: userList.count > 0 ? userList.currentUserName().charAt(0).toUpperCase() : "?"
                    color: "white"
                    font.family: NimbusTokens.fontFamily
                    font.pixelSize: 28
                }
            }
            Text {
                id: userName
                Layout.alignment: Qt.AlignHCenter
                text: userList.count > 0 ? userList.currentUserName() : ""
                color: NimbusTokens.colors(true).label
                font.family: NimbusTokens.fontFamily
                font.pixelSize: NimbusTokens.type.t17.size
            }

            // Selector de usuario (userModel del daemon).
            UserSelector {
                id: userList
                Layout.alignment: Qt.AlignHCenter
                fontFamily: NimbusTokens.fontFamily
                textColor: NimbusTokens.colors(true).label
                Component.onCompleted: {
                    var arr = [];
                    for (var i = 0; i < userModel.count; i++)
                        arr.push({
                            "name": userModel.data(userModel.index(i, 0), Qt.UserRole + 2),
                            "realName": userModel.data(userModel.index(i, 0), Qt.UserRole + 3)
                        });
                    users = arr;
                }
                function currentUserName() {
                    if (users.length === 0)
                        return "";
                    var u = users[currentIndex];
                    return u.realName || u.name;
                }
                onUserSelected: function (i) {
                    userModel.lastIndex = i;
                }
            }

            // Campo de contraseña.
            TextField {
                id: pwField
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 280
                Layout.preferredHeight: 36
                placeholderText: "Contraseña"
                echoMode: TextInput.Password
                font.family: NimbusTokens.fontFamily
                font.pixelSize: NimbusTokens.type.t15.size
                focus: true
                onAccepted: loginButton.clicked()
                // macOS: Esc limpia el campo y devuelve el foco a la tarjeta
                // (al botón de login); no interfiere con Enter (onAccepted).
                Keys.onEscapePressed: {
                    pwField.text = "";
                    failLabel.text = "";
                    loginButton.forceActiveFocus();
                }
                background: Rectangle {
                    radius: NimbusTokens.radii.rMd
                    color: "#1C1C1E"
                    opacity: 0.9
                    border.color: pwField.activeFocus ? NimbusTokens.colors(true).accent : "#38383A"
                    border.width: pwField.activeFocus ? 2 : 1
                }
            }
            Text {
                id: failLabel
                Layout.alignment: Qt.AlignHCenter
                visible: text !== ""
                color: NimbusTokens.colors(true).destructive
                font.family: NimbusTokens.fontFamily
                font.pixelSize: NimbusTokens.type.t13.size
            }

            Button {
                id: loginButton
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 280
                Layout.preferredHeight: 36
                text: "Iniciar sesión"
                font.family: NimbusTokens.fontFamily
                font.pixelSize: NimbusTokens.type.t15.size
                onClicked: sddm.login(userModel.data(userModel.index(userList.currentIndex, 0), Qt.UserRole + 2), pwField.text, sessionBar.sessionIndex)
                background: Rectangle {
                    radius: NimbusTokens.radii.rMd
                    color: NimbusTokens.colors(true).accent
                }
                contentItem: Text {
                    text: loginButton.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: NimbusTokens.fontFamily
                    font.pixelSize: NimbusTokens.type.t15.size
                }
            }

            // Sesión + teclado + apagar/reiniciar.
            SessionBar {
                id: sessionBar
                Layout.alignment: Qt.AlignHCenter
                fontFamily: NimbusTokens.fontFamily
                textColor: NimbusTokens.colors(true).label
                Component.onCompleted: {
                    var s = [];
                    for (var i = 0; i < sessionModel.count; i++)
                        s.push({
                            "name": sessionModel.data(sessionModel.index(i, 0), Qt.UserRole + 4)
                        });
                    sessions = s;
                    sessionIndex = sessionModel.lastIndex;
                }
                onSessionSelected: function (i) {
                    sessionModel.lastIndex = i;
                }
                onPowerRequested: function (action) {
                    if (action === "reboot")
                        sddm.reboot();
                    else
                        sddm.powerOff();
                }
            }
        }
    }

    Connections {
        target: sddm
        function onLoginSucceeded() {
            failLabel.text = "";
        }
        function onLoginFailed() {
            failLabel.text = "Contraseña incorrecta, inténtalo de nuevo";
            pwField.text = "";
            pwField.focus = true;
        }
    }
}
