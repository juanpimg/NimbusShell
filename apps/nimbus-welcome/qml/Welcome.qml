// Welcome.qml — wizard F9-T02/T03 (7 pasos: bienvenida, idioma, wifi,
// cuenta, apariencia, diseño, apps+tour). Tokens Tahoe inline (contrato §2 [HIG]):
// label #000000/#FFFFFF, accent #007AFF/#0A84FF, bg #FFFFFF/#000000,
// bgElevated #FFFFFF/#2C2C2E, bg2 #F2F2F7/#1C1C1E, radios r-md 10-12,
// ventana 760x540, Inter, spacing escala 4/8/12/16/20/24/32.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "I18n.js" as I18n

ApplicationWindow {
    id: root
    objectName: "welcomeWindow"
    width: 760
    height: 540
    minimumWidth: 640
    minimumHeight: 480
    visible: true
    title: "Nimbus"
    color: "transparent"

    // Paleta hoisted en `c` (qmllint del sistema rompe con llamadas
    // encadenadas en un mismo fichero; ver F3-T01).
    property bool isDark: backend.appearance === "dark"
    property var lightPal: ({
            "label": "#000000",
            "label2": "#3C3C43",
            "bg": "#FFFFFF",
            "bgElevated": "#FFFFFF",
            "bg2": "#F2F2F7",
            "accent": "#007AFF",
            "separator": "#C6C6C8"
        })
    property var darkPal: ({
            "label": "#FFFFFF",
            "label2": "#EBEBF5",
            "bg": "#000000",
            "bgElevated": "#2C2C2E",
            "bg2": "#1C1C1E",
            "accent": "#0A84FF",
            "separator": "#38383A"
        })
    property var c: isDark ? darkPal : lightPal
    property var stepNames: ["Bienvenida", "Idioma", "Wi-Fi", "Tu cuenta", "Apariencia", "Diseño", "Apps recomendadas"]
    property string selSsid: ""
    property string langStamp: "" // zero-width: reevalúa tr() al cambiar idioma
    function t(s) {
        return I18n.tr(s) + root.langStamp;
    }
    function goLang(code) {
        backend.setLanguage(code);
        I18n.setLang(code);
        root.langStamp = (root.langStamp === "") ? "​" : "";
    }

    Component.onCompleted: {
        I18n.setLang(backend.language);
        backend.scanWifi();
    }

    Rectangle {
        anchors.fill: parent
        color: c.bg2
        radius: 12
        border.color: c.separator
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            // Cabecera: puntos + barra de progreso.
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: 7
                    Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        color: index <= backend.step ? c.accent : c.separator
                        Accessible.name: root.stepNames[index]
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                Text {
                    text: (backend.step + 1) + " " + root.t("de") + " 7 · " + root.t(root.stepNames[backend.step])
                    font.family: "Inter"
                    font.pixelSize: 12
                    color: c.label2
                }
            }
            Rectangle {
                Layout.fillWidth: true
                height: 4
                radius: 2
                color: c.separator
                Rectangle {
                    width: parent.width * (backend.step + 1) / 7
                    height: parent.height
                    radius: 2
                    color: c.accent
                    Behavior on width {
                        NumberAnimation {
                            duration: 250
                        }
                    }
                }
            }

            // Páginas.
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: backend.step

                // 0 Bienvenida.
                Item {
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 80, 520)
                        spacing: 12
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: 72
                            height: 72
                            radius: 16
                            color: c.accent
                            Text {
                                anchors.centerIn: parent
                                text: "N"
                                font.family: "Inter"
                                font.pixelSize: 40
                                font.bold: true
                                color: "white"
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: root.t("Te damos la bienvenida a Nimbus")
                            font.family: "Inter"
                            font.pixelSize: 28
                            font.weight: 600
                            color: c.label
                            wrapMode: Text.WordWrap
                        }
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: root.t("Un escritorio familiar, rápido y tuyo. Este asistente te deja todo listo en menos de 5 minutos.")
                            font.family: "Inter"
                            font.pixelSize: 13
                            color: c.label2
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // 1 Idioma.
                Item {
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 80, 420)
                        spacing: 12
                        Text {
                            text: root.t("Idioma")
                            font.family: "Inter"
                            font.pixelSize: 22
                            font.weight: 600
                            color: c.label
                        }
                        Text {
                            text: root.t("Elige tu idioma. Se aplicará a todo el sistema.")
                            font.family: "Inter"
                            font.pixelSize: 13
                            color: c.label2
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        ComboBox {
                            Layout.fillWidth: true
                            model: [root.t("Español"), root.t("Inglés")]
                            currentIndex: backend.language === "en" ? 1 : 0
                            Accessible.name: root.t("Idioma")
                            onActivated: function (i) {
                                root.goLang(i === 1 ? "en" : "es");
                            }
                        }
                    }
                }

                // 2 Wi-Fi.
                Item {
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 80, 460)
                        spacing: 8
                        Text {
                            text: root.t("Wi-Fi")
                            font.family: "Inter"
                            font.pixelSize: 22
                            font.weight: 600
                            color: c.label
                        }
                        Text {
                            text: root.t("Conéctate para terminar de configurar el sistema. Puedes omitir este paso.")
                            font.family: "Inter"
                            font.pixelSize: 13
                            color: c.label2
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        ListView {
                            Layout.fillWidth: true
                            height: 120
                            clip: true
                            model: backend.wifiNetworks
                            delegate: Rectangle {
                                width: ListView.view.width
                                height: 32
                                radius: 8
                                color: root.selSsid === modelData ? c.accent : "transparent"
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    text: modelData
                                    font.family: "Inter"
                                    font.pixelSize: 13
                                    color: root.selSsid === modelData ? "white" : c.label
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        root.selSsid = modelData;
                                    }
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            TextField {
                                id: wifiPass
                                Layout.fillWidth: true
                                echoMode: TextInput.Password
                                placeholderText: root.t("Contraseña")
                                Accessible.name: root.t("Contraseña")
                            }
                            Button {
                                text: root.t("Buscar redes")
                                onClicked: {
                                    backend.scanWifi();
                                }
                            }
                            Button {
                                text: root.t("Conectar")
                                highlighted: true
                                onClicked: {
                                    backend.connectWifi(root.selSsid, wifiPass.text);
                                }
                            }
                        }
                        Text {
                            text: backend.wifiStatus
                            font.family: "Inter"
                            font.pixelSize: 12
                            color: c.label2
                        }
                    }
                }

                // 3 Cuenta/avatar.
                Item {
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 80, 420)
                        spacing: 12
                        Text {
                            text: root.t("Tu cuenta")
                            font.family: "Inter"
                            font.pixelSize: 22
                            font.weight: 600
                            color: c.label
                        }
                        Text {
                            text: root.t("¿Cómo te llamas? Tu nombre aparece en el menú y la pantalla de bloqueo.")
                            font.family: "Inter"
                            font.pixelSize: 13
                            color: c.label2
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        RowLayout {
                            spacing: 16
                            Rectangle {
                                width: 72
                                height: 72
                                radius: 36
                                color: backend.avatarPath === "" ? c.accent : "transparent"
                                clip: true
                                Image {
                                    anchors.fill: parent
                                    source: backend.avatarPath
                                    fillMode: Image.PreserveAspectCrop
                                    visible: backend.avatarPath !== ""
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: backend.userName.length > 0 ? backend.userName.charAt(0).toUpperCase() : "?"
                                    font.family: "Inter"
                                    font.pixelSize: 32
                                    font.bold: true
                                    color: "white"
                                    visible: backend.avatarPath === ""
                                }
                            }
                            ColumnLayout {
                                spacing: 8
                                TextField {
                                    id: nameField
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 240
                                    text: backend.userName
                                    placeholderText: root.t("Tu nombre")
                                    Accessible.name: root.t("Tu nombre")
                                    onEditingFinished: {
                                        backend.setUserName(text);
                                    }
                                }
                                Button {
                                    text: root.t("Elegir foto…")
                                    onClicked: {
                                        avatarDialog.open();
                                    }
                                }
                            }
                        }
                    }
                }

                // 4 Apariencia.
                Item {
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 80, 460)
                        spacing: 12
                        Text {
                            text: root.t("Apariencia")
                            font.family: "Inter"
                            font.pixelSize: 22
                            font.weight: 600
                            color: c.label
                        }
                        Text {
                            text: root.t("Claro u oscuro y tu color de acento. Se aplica con nimbus-theme.")
                            font.family: "Inter"
                            font.pixelSize: 13
                            color: c.label2
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        RowLayout {
                            spacing: 8
                            RadioButton {
                                text: root.t("Claro")
                                contentItem: Text {
                                    text: parent.text
                                    font.family: "Inter"
                                    font.pixelSize: 13
                                    color: c.label
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: parent.indicator.width + parent.spacing
                                }
                                checked: backend.appearance === "light"
                                onClicked: {
                                    backend.setAppearance("light");
                                }
                            }
                            RadioButton {
                                text: root.t("Oscuro")
                                contentItem: Text {
                                    text: parent.text
                                    font.family: "Inter"
                                    font.pixelSize: 13
                                    color: c.label
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: parent.indicator.width + parent.spacing
                                }
                                checked: backend.appearance === "dark"
                                onClicked: {
                                    backend.setAppearance("dark");
                                }
                            }
                        }
                        Text {
                            text: root.t("Color de acento")
                            font.family: "Inter"
                            font.pixelSize: 13
                            font.bold: true
                            color: c.label
                        }
                        RowLayout {
                            spacing: 8
                            Repeater {
                                model: ["#0A84FF", "#BF5AF2", "#30D158", "#FF9F0A", "#FF453A"]
                                Rectangle {
                                    width: 36
                                    height: 36
                                    radius: 18
                                    color: modelData
                                    border.color: backend.accent === modelData ? c.label : "transparent"
                                    border.width: 2
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            backend.setAccent(modelData);
                                        }
                                    }
                                }
                            }
                            Button {
                                text: root.t("Aplicar")
                                onClicked: {
                                    backend.applyAppearance();
                                }
                            }
                        }
                    }
                }

                // 5 Diseño (F9-T03): Mac / Windows / Nimbus.
                Item {
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 80, 560)
                        spacing: 8
                        Text {
                            text: root.t("Diseño")
                            font.family: "Inter"
                            font.pixelSize: 22
                            font.weight: 600
                            color: c.label
                        }
                        Text {
                            text: root.t("Elige cómo se comporta tu escritorio. Mac es el predeterminado.")
                            font.family: "Inter"
                            font.pixelSize: 13
                            color: c.label2
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            // Tarjeta reutilizable: id, título, descripción, semáforos a la izq/der.
                            Repeater {
                                model: [
                                    {
                                        "id": "mac",
                                        "title": "Mac",
                                        "desc": "Cmd con Meta, semáforos a la izquierda, Dock abajo.",
                                        "left": true
                                    },
                                    {
                                        "id": "windows",
                                        "title": "Windows",
                                        "desc": "Ctrl y Alt clásicos, botones a la derecha.",
                                        "left": false
                                    },
                                    {
                                        "id": "nimbus",
                                        "title": "Nimbus",
                                        "desc": "Mezcla: Meta para apps, Ctrl para Spaces.",
                                        "left": true
                                    }
                                ]
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 132
                                    radius: 10
                                    color: backend.layout === modelData.id ? c.bgElevated : c.bg2
                                    border.color: backend.layout === modelData.id ? c.accent : c.separator
                                    border.width: backend.layout === modelData.id ? 2 : 1
                                    Accessible.name: modelData.title
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 4
                                        // Mini-preview: barra + ventana con semáforos + dock.
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 56
                                            radius: 6
                                            color: c.bg
                                            border.color: c.separator
                                            border.width: 1
                                            Rectangle {
                                                anchors.top: parent.top
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                height: 12
                                                radius: 3
                                                color: c.bg2
                                            }
                                            Row {
                                                anchors.top: parent.top
                                                anchors.topMargin: 16
                                                anchors.left: parent.left
                                                anchors.leftMargin: modelData.left ? 4 : 0
                                                anchors.right: parent.right
                                                anchors.rightMargin: modelData.left ? 0 : 4
                                                spacing: 2
                                                layoutDirection: modelData.left ? Qt.LeftToRight : Qt.RightToLeft
                                                Repeater {
                                                    model: 3
                                                    Rectangle {
                                                        width: 6
                                                        height: 6
                                                        radius: 3
                                                        color: ["#FF5F57", "#FEBC2E", "#28C840"][index]
                                                    }
                                                }
                                            }
                                            Rectangle {
                                                anchors.bottom: parent.bottom
                                                anchors.bottomMargin: 4
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: 44
                                                height: 8
                                                radius: 4
                                                color: c.accent
                                            }
                                        }
                                        Text {
                                            text: (backend.layout === modelData.id ? "● " : "○ ") + modelData.title
                                            font.family: "Inter"
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: c.label
                                        }
                                        Text {
                                            text: root.t(modelData.desc)
                                            font.family: "Inter"
                                            font.pixelSize: 11
                                            color: c.label2
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            backend.setLayout(modelData.id);
                                        }
                                    }
                                }
                            }
                        }
                        RowLayout {
                            spacing: 8
                            Button {
                                text: root.t("Aplicar diseño")
                                highlighted: true
                                Accessible.name: root.t("Aplicar diseño")
                                onClicked: {
                                    backend.applyLayout();
                                }
                            }
                            Text {
                                text: root.t("Elegido:") + " " + backend.layout
                                font.family: "Inter"
                                font.pixelSize: 12
                                color: c.label2
                            }
                        }
                    }
                }

                // 6 Apps recomendadas + tour final.
                Item {
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 80, 480)
                        spacing: 8
                        Text {
                            text: root.t("Apps recomendadas")
                            font.family: "Inter"
                            font.pixelSize: 22
                            font.weight: 600
                            color: c.label
                        }
                        Text {
                            text: root.t("Marca las que quieras descubrir. No se instala nada ahora: las verás en Descubrir.")
                            font.family: "Inter"
                            font.pixelSize: 13
                            color: c.label2
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        GridLayout {
                            columns: 2
                            CheckBox {
                                text: "Firefox — navegador"
                                checked: backend.selectedApps.indexOf("firefox") >= 0
                                onClicked: {
                                    backend.toggleApp("firefox");
                                }
                            }
                            CheckBox {
                                text: "VLC — vídeo"
                                checked: backend.selectedApps.indexOf("vlc") >= 0
                                onClicked: {
                                    backend.toggleApp("vlc");
                                }
                            }
                            CheckBox {
                                text: "GIMP — imagen"
                                checked: backend.selectedApps.indexOf("gimp") >= 0
                                onClicked: {
                                    backend.toggleApp("gimp");
                                }
                            }
                            CheckBox {
                                text: "LibreOffice — oficina"
                                checked: backend.selectedApps.indexOf("libreoffice") >= 0
                                onClicked: {
                                    backend.toggleApp("libreoffice");
                                }
                            }
                        }
                        Text {
                            text: root.t("Listo para despegar")
                            font.family: "Inter"
                            font.pixelSize: 15
                            font.bold: true
                            color: c.label
                        }
                        Text {
                            text: root.t("Ya está todo. Este es tu escritorio Nimbus: menú arriba, Dock abajo, Spotlight con Cmd+Espacio.")
                            font.family: "Inter"
                            font.pixelSize: 13
                            color: c.label2
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // Pie: Atrás / Omitir / Siguiente.
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Button {
                    text: root.t("Atrás")
                    enabled: backend.step > 0
                    Accessible.name: root.t("Atrás")
                    onClicked: {
                        backend.back();
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                Button {
                    text: root.t("Omitir")
                    visible: backend.step < 6
                    onClicked: {
                        backend.skip();
                    }
                }
                Button {
                    text: backend.step === 6 ? root.t("Terminar") : root.t("Siguiente")
                    highlighted: true
                    Accessible.name: backend.step === 6 ? root.t("Terminar") : root.t("Siguiente")
                    onClicked: {
                        backend.next();
                    }
                }
            }
        }
    }

    FileDialog {
        id: avatarDialog
        title: root.t("Elegir foto…")
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp)", "All (*)"]
        onAccepted: {
            backend.setAvatarPath(selectedFile.toString());
        }
    }
}
