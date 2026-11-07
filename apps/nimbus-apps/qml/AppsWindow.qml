// Ventana Apps estilo Tahoe (R-APPSVIEW): centrada 1000x700, categorías
// fijas + Suggestions, vistas Icons/List, buscador, teclado completo.
// Tokens del contrato §2: bg #FFFFFF/#2C2C2E, label, accent #007AFF/#0A84FF,
// radio ventana 16, radios md 10-12, t12/t13, spacing 4/8/12/16/20.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// F6-T07 — TECLADO Y ACCESIBILIDAD (todos sin ratón, documentados aquí):
//   Tab / Shift+Tab .... Buscador → Vista → Categorías → Rejilla/Lista →
//                        Buscador (sin trampas; KeyNavigation)
//   ← → ↑ ↓ ............ mueve selección (rejilla: cols reales; lista: ±1)
//   Home / End ......... primera / última app (categorías y rejilla/lista)
//   RePág / AvPág ...... ±10 apps (rejilla/lista)
//   Enter .............. lanza la app seleccionada / entra en la rejilla
//   Esc ................ oculta la ventana (NO cierra el proceso)
//   Espacio ............ activa el botón enfocado (vista, categoría)
// Foco visible: anillo accent 2px sobre el control enfocado (≥3:1
// non-text en ambos temas). Contraste texto ≥4.5:1 en ambos temas.
// Hit targets: filas categorías 36px, filas lista 40px, celdas 110x104,
// buscador 32px. Announce de vista/categoría/selección a lectores.
ApplicationWindow {
    id: root

    property bool dark: true
    property color bgCol: dark ? "#1C1C1E" : "#F2F2F7"
    property color cardCol: dark ? "#2C2C2E" : "#FFFFFF"
    property color labelCol: dark ? "#FFFFFF" : "#000000"
    property color label2Col: dark ? "#98989D" : "#8E8E93"
    property color accentCol: dark ? "#0A84FF" : "#007AFF"
    property color searchCol: dark ? "#38383A" : "#E3E3E8"
    property int selIndex: 0
    property var cats: ["Todas", "Suggestions", "Productividad", "Desarrollo", "Gráficos", "Juegos", "Multimedia", "Utilidades", "Internet", "Ajustes"]
    // F6-T07: token de foco visible (anillo accent 2px).
    property int focusW: 2

    // F6-T07: anuncia cambios a lectores (Orca/AT-SPI vía QAccessible).
    function announce(msg) {
        Accessible.announce(root, msg);
    }

    function announceSel() {
        root.announce("App " + (root.selIndex + 1) + " de " + appModel.count);
    }

    width: 1000
    height: 700
    minimumWidth: 800
    minimumHeight: 560
    visible: true
    title: "Apps"
    color: "transparent"
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
        } else if (event.key === Qt.Key_Home) {
            root.selIndex = 0;
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            root.selIndex = Math.max(0, appModel.count - 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_PageDown) {
            root.selIndex = Math.min(appModel.count - 1, root.selIndex + 10);
            event.accepted = true;
        } else if (event.key === Qt.Key_PageUp) {
            root.selIndex = Math.max(0, root.selIndex - 10);
            event.accepted = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: root.dark ? Qt.rgba(0.12, 0.14, 0.18, 0.82) : Qt.rgba(0.96, 0.97, 0.99, 0.85)
        border.color: Qt.rgba(1, 1, 1, root.dark ? 0.2 : 0.25)
        border.width: 1

        // Top specular rim highlight
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: 1
            radius: 20
            color: Qt.rgba(1, 1, 1, root.dark ? 0.4 : 0.65)
        }

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
                    Accessible.name: "Buscar apps"
                    Accessible.description: "Filtra por nombre. Tab pasa al selector de vista. Escape oculta la ventana."
                    Accessible.role: Accessible.EditableText
                    // F6-T07: Tab/Shift+Tab navegan (sin trampas).
                    KeyNavigation.tab: viewBtn
                    KeyNavigation.backtab: appModel.listMode ? list : grid
                    onTextChanged: {
                        appModel.filter = text;
                        root.selIndex = 0;
                    }
                    // F6-T07: Esc oculta (antes Qt.quit() mataba el proceso,
                    // inconsistente con Shortcut Escape→hide de abajo).
                    Keys.onEscapePressed: root.hide()
                    Component.onCompleted: forceActiveFocus()

                    background: Rectangle {
                        radius: 10
                        color: root.searchCol
                        implicitHeight: 32
                        border.color: search.activeFocus ? root.accentCol : "transparent"
                        border.width: root.focusW
                    }
                }

                Button {
                    id: viewBtn

                    text: appModel.listMode ? "☰ Lista" : "▦ Iconos"
                    font.pixelSize: 12
                    onClicked: {
                        appModel.listMode = !appModel.listMode;
                        root.announce(appModel.listMode ? "Vista lista" : "Vista iconos");
                    }
                    Accessible.name: "Cambiar vista"
                    Accessible.description: "Alterna entre vista de iconos y de lista. Pulsa Espacio para cambiar."
                    // F6-T07: tramo Tab del ciclo.
                    KeyNavigation.tab: catList
                    KeyNavigation.backtab: search
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 16

                // Categorías fijas
                ListView {
                    // Tab/Shift+Tab: los mueve KeyNavigation.

                    id: catList

                    Layout.preferredWidth: 180
                    Layout.fillHeight: true
                    model: root.cats
                    spacing: 4
                    // Refleja la categoría inicial del modelo (--category, F6-T05).
                    currentIndex: Math.max(0, root.cats.indexOf(appModel.category))
                    // F6-T07: parada Tab + teclado completo + rol accesible.
                    activeFocusOnTab: true
                    KeyNavigation.tab: appModel.listMode ? list : grid
                    KeyNavigation.backtab: viewBtn
                    Accessible.role: Accessible.List
                    Accessible.name: "Categorías"
                    Accessible.description: "Flechas arriba y abajo para cambiar de categoría. Enter pasa a las apps."
                    Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_Down) {
                            catList.currentIndex = Math.min(catList.currentIndex + 1, catList.count - 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            catList.currentIndex = Math.max(catList.currentIndex - 1, 0);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Home) {
                            catList.currentIndex = 0;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_End) {
                            catList.currentIndex = catList.count - 1;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Right) {
                            (appModel.listMode ? list : grid).forceActiveFocus();
                            root.announceSel();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            root.hide();
                            event.accepted = true;
                        }
                    }
                    onCurrentIndexChanged: {
                        appModel.category = root.cats[currentIndex];
                        root.selIndex = 0;
                        if (catList.activeFocus)
                            root.announce(root.cats[currentIndex]);
                    }

                    delegate: Rectangle {
                        width: catList.width
                        height: 36 // F6-T07: hit target 36px (antes 28)
                        radius: 8
                        color: ListView.isCurrentItem ? root.accentCol : "transparent"
                        // F6-T07: anillo de foco visible.
                        border.color: (catList.activeFocus && ListView.isCurrentItem) ? root.labelCol : "transparent"
                        border.width: (catList.activeFocus && ListView.isCurrentItem) ? root.focusW : 0
                        Accessible.role: Accessible.ListItem
                        Accessible.name: modelData

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
                        // F6-T07: parada Tab (cierra el ciclo hacia el buscador).
                        activeFocusOnTab: true
                        KeyNavigation.tab: search
                        KeyNavigation.backtab: catList
                        Accessible.role: Accessible.Grid
                        Accessible.name: "Apps, vista iconos"
                        Accessible.description: "Flechas para elegir app. Enter lanza. Tab vuelve al buscador."
                        Keys.onPressed: function (event) {
                            var cols = Math.max(1, Math.floor(grid.width / grid.cellWidth));
                            if (event.key === Qt.Key_Right) {
                                root.selIndex = Math.min(appModel.count - 1, root.selIndex + 1);
                                root.announceSel();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Left) {
                                root.selIndex = Math.max(0, root.selIndex - 1);
                                root.announceSel();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down) {
                                root.selIndex = Math.min(appModel.count - 1, root.selIndex + cols);
                                root.announceSel();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                root.selIndex = Math.max(0, root.selIndex - cols);
                                root.announceSel();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Home) {
                                root.selIndex = 0;
                                root.announceSel();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_End) {
                                root.selIndex = Math.max(0, appModel.count - 1);
                                root.announceSel();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_PageDown) {
                                root.selIndex = Math.min(appModel.count - 1, root.selIndex + 10);
                                root.announceSel();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_PageUp) {
                                root.selIndex = Math.max(0, root.selIndex - 10);
                                root.announceSel();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                appModel.launch(root.selIndex);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                root.hide();
                                event.accepted = true;
                            }
                        }

                        delegate: Item {
                            width: 110
                            height: 104
                            Accessible.role: Accessible.ListItem
                            Accessible.name: appName

                            Column {
                                anchors.centerIn: parent
                                spacing: 4

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 64
                                    height: 64
                                    radius: 12
                                    color: GridView.isCurrentItem ? root.accentCol + "33" : root.cardCol
                                    // F6-T07: selección = anillo accent; con foco
                                    // de teclado el anillo pasa a label (visible
                                    // en ambos temas, ≥3:1 non-text).
                                    border.color: GridView.isCurrentItem ? (grid.activeFocus ? root.labelCol : root.accentCol) : "transparent"
                                    border.width: GridView.isCurrentItem ? root.focusW : 0

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
                        // F6-T07: parada Tab (cierra el ciclo hacia el buscador).
                        activeFocusOnTab: true
                        KeyNavigation.tab: search
                        KeyNavigation.backtab: catList
                        Accessible.role: Accessible.List
                        Accessible.name: "Apps, vista lista"
                        Accessible.description: "Flechas arriba y abajo para elegir app. Enter lanza. Tab vuelve al buscador."
                        Keys.onPressed: function (event) {
                            if (event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
                                root.selIndex = Math.min(appModel.count - 1, root.selIndex + 1);
                                root.announceSel();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
                                root.selIndex = Math.max(0, root.selIndex - 1);
                                root.announceSel();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Home) {
                                root.selIndex = 0;
                                root.announceSel();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_End) {
                                root.selIndex = Math.max(0, appModel.count - 1);
                                root.announceSel();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_PageDown) {
                                root.selIndex = Math.min(appModel.count - 1, root.selIndex + 10);
                                root.announceSel();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_PageUp) {
                                root.selIndex = Math.max(0, root.selIndex - 10);
                                root.announceSel();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                appModel.launch(root.selIndex);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                root.hide();
                                event.accepted = true;
                            }
                        }

                        delegate: Rectangle {
                            width: list.width
                            height: 40 // F6-T07: hit target 40px (antes 36)
                            radius: 8
                            color: ListView.isCurrentItem ? root.accentCol + "33" : "transparent"
                            // F6-T07: selección = tinte accent; con foco de
                            // teclado el borde pasa a label (visible, ≥3:1).
                            border.color: ListView.isCurrentItem ? (list.activeFocus ? root.labelCol : root.accentCol) : "transparent"
                            border.width: ListView.isCurrentItem ? root.focusW : 0
                            Accessible.role: Accessible.ListItem
                            Accessible.name: appName + ", " + appCategory

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
                font.pixelSize: 12 // F6-T07: ≥12px (antes 11)
                color: root.label2Col
                horizontalAlignment: Text.AlignRight
                Accessible.name: appModel.count + " aplicaciones"
            }
        }
    }

    // Teclado completo: flechas / Home-End / RePág-AvPág / Enter / Esc.
    // (Fallback raíz: con foco en buscador/botón; las vistas aceptan sus
    // propias teclas y anuncian. Sin trampas: Tab lo mueve KeyNavigation.)
    Shortcut {
        sequence: "Escape"
        onActivated: root.hide()
    }

    Shortcut {
        sequence: "Return"
        onActivated: appModel.launch(root.selIndex)
    }
}
