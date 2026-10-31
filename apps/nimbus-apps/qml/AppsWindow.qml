import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Ventana Apps estilo Tahoe (R-APPSVIEW): centrada 1000x700, categorías
// fijas + Suggestions, vistas Icons/List, buscador, teclado completo.
// Tokens del contrato §2: bg #FFFFFF/#2C2C2E, label, accent #007AFF/#0A84FF,
// radio ventana 16, radios md 10-12, t12/t13, spacing 4/8/12/16/20.
ApplicationWindow {
    id: root
    width: 1000
    height: 700
    minimumWidth: 800
    minimumHeight: 560
    visible: true
    title: "Apps"
    color: "transparent"
    property bool dark: false

    property color bgCol: dark ? "#1C1C1E" : "#F2F2F7"
    property color cardCol: dark ? "#2C2C2E" : "#FFFFFF"
    property color labelCol: dark ? "#FFFFFF" : "#000000"
    property color label2Col: dark ? "#98989D" : "#8E8E93"
    property color accentCol: dark ? "#0A84FF" : "#007AFF"
    property color searchCol: dark ? "#38383A" : "#E3E3E8"

    property int selIndex: 0
    property var cats: ["Todas", "Suggestions", "Productividad", "Desarrollo", "Gráficos", "Juegos", "Multimedia", "Utilidades", "Internet", "Ajustes"]

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: root.bgCol
        border.color: root.dark ? "#38383A" : "#C6C6C8"
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            // Buscador + toggle Icons/List
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                TextField {
                    id: search
                    Layout.fillWidth: true
                    placeholderText: "Buscar apps"
                    font.pixelSize: 13
                    color: root.labelCol
                    placeholderTextColor: root.label2Col
                    background: Rectangle {
                        radius: 10
                        color: root.searchCol
                        implicitHeight: 32
                    }
                    onTextChanged: {
                        appModel.filter = text;
                        root.selIndex = 0;
                    }
                    Keys.onEscapePressed: Qt.quit()
                    Component.onCompleted: forceActiveFocus()
                }
                Button {
                    text: appModel.listMode ? "☰ Lista" : "▦ Iconos"
                    font.pixelSize: 12
                    onClicked: appModel.listMode = !appModel.listMode
                    Accessible.name: "Cambiar vista"
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 16

                // Categorías fijas
                ListView {
                    id: catList
                    Layout.preferredWidth: 180
                    Layout.fillHeight: true
                    model: root.cats
                    spacing: 4
                    // Refleja la categoría inicial del modelo (--category, F6-T05).
                    currentIndex: Math.max(0, root.cats.indexOf(appModel.category))
                    delegate: Rectangle {
                        width: catList.width
                        height: 28
                        radius: 8
                        color: ListView.isCurrentItem ? root.accentCol : "transparent"
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            text: modelData
                            font.pixelSize: 13
                            color: ListView.isCurrentItem ? "white" : root.labelCol
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                catList.currentIndex = index;
                                appModel.category = modelData;
                                root.selIndex = 0;
                            }
                        }
                    }
                    onCurrentIndexChanged: {
                        appModel.category = root.cats[currentIndex];
                        root.selIndex = 0;
                    }
                }

                // Grid / lista de apps
                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: appModel.listMode ? 1 : 0

                    GridView {
                        id: grid
                        model: appModel
                        cellWidth: 110
                        cellHeight: 104
                        clip: true
                        highlightFollowsCurrentItem: true
                        currentIndex: root.selIndex
                        onCurrentIndexChanged: root.selIndex = currentIndex
                        delegate: Item {
                            width: 110
                            height: 104
                            Column {
                                anchors.centerIn: parent
                                spacing: 4
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 64
                                    height: 64
                                    radius: 12
                                    color: GridView.isCurrentItem ? root.accentCol + "33" : root.cardCol
                                    border.color: GridView.isCurrentItem ? root.accentCol : "transparent"
                                    border.width: 2
                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        source: "image://nimbusicons/" + (appIcon || "") + "?name=" + (appName || "?")
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 100
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.Wrap
                                    text: appName
                                    font.pixelSize: 12
                                    color: root.labelCol
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    grid.currentIndex = index;
                                    root.selIndex = index;
                                }
                                onDoubleClicked: appModel.launch(index)
                            }
                        }
                    }

                    ListView {
                        id: list
                        model: appModel
                        clip: true
                        spacing: 2
                        currentIndex: root.selIndex
                        onCurrentIndexChanged: root.selIndex = currentIndex
                        delegate: Rectangle {
                            width: list.width
                            height: 36
                            radius: 8
                            color: ListView.isCurrentItem ? root.accentCol + "33" : "transparent"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12
                                Rectangle {
                                    width: 24
                                    height: 24
                                    radius: 6
                                    color: root.cardCol
                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        source: "image://nimbusicons/" + (appIcon || "") + "?name=" + (appName || "?")
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: appName
                                    font.pixelSize: 13
                                    color: root.labelCol
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: appCategory
                                    font.pixelSize: 12
                                    color: root.label2Col
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    list.currentIndex = index;
                                    root.selIndex = index;
                                }
                                onDoubleClicked: appModel.launch(index)
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: appModel.count + " apps"
                font.pixelSize: 11
                color: root.label2Col
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    // Teclado completo: flechas / Enter / Esc
    Shortcut {
        sequence: "Escape"
        onActivated: root.hide()
    }
    Shortcut {
        sequence: "Return"
        onActivated: appModel.launch(root.selIndex)
    }
    Keys.onPressed: event => {
        var cols = Math.max(1, Math.floor(grid.width / grid.cellWidth));
        if (event.key === Qt.Key_Right) {
            root.selIndex = Math.min(appModel.count - 1, root.selIndex + 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            root.selIndex = Math.max(0, root.selIndex - 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            root.selIndex = Math.min(appModel.count - 1, root.selIndex + (appModel.listMode ? 1 : cols));
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            root.selIndex = Math.max(0, root.selIndex - (appModel.listMode ? 1 : cols));
            event.accepted = true;
        }
    }
}
