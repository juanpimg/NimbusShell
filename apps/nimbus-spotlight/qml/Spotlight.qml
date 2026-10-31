// Spotlight.qml — overlay centrado ~680px (F6-T01, contrato §3).
// Glass oscuro, campo grande, resultados + preview, footer Cmd+1..4.
// Tokens dark §2.1 hardcodeados (light/dark completo vive en F8-T05).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    objectName: "spotlightWindow"
    width: 680
    height: 460
    visible: true
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
    color: "transparent"
    title: "Spotlight"

    property int currentIndex: 0
    property string tab: "apps" // apps | files | actions | clipboard
    property var tabNames: ({
            "apps": "Apps",
            "files": "Archivos",
            "actions": "Acciones",
            "clipboard": "Portapapeles"
        })
    property var filtered: []
    property string lastQuery: ""

    function refreshFilter() {
        var all = backend.matches;
        var q = searchField.text;
        root.lastQuery = q;
        if (root.tab === "clipboard") {
            root.filtered = all;
        } else {
            root.filtered = all.filter(function (m) {
                return m.category === root.tab;
            });
        }
        // Si la pestaña queda vacía pero hay resultados, mostrar todos.
        if (root.filtered.length === 0 && all.length > 0 && q !== "")
            root.filtered = all;
        root.currentIndex = 0;
    }

    function doSearch() {
        if (root.tab === "clipboard")
            backend.clipboardHistory();
        else
            backend.search(searchField.text);
    }

    Connections {
        target: backend
        function onMatchesChanged() {
            root.refreshFilter();
        }
    }

    Component.onCompleted: {
        if (initialQuery !== "")
            searchField.text = initialQuery; // onTextChanged+debounce lanza
        searchField.forceActiveFocus();
    }

    // Cierra al perder foco / Esc (sin robar teclado oculto: visible=false).
    onActiveChanged: {
        if (!root.active && root.visible)
            root.visible = false;
    }

    Rectangle {
        anchors.fill: parent
        radius: 20 // r-lg §2.3
        color: "#2C2C2E" // bgElevated dark [HIG]
        opacity: 0.94
        border.color: "#38383A" // separator opaco dark [HIG]
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        // Campo de búsqueda grande.
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            spacing: 8
            Text {
                text: "🔍"
                font.pixelSize: 20
                Accessible.name: "Buscar"
            }
            TextField {
                id: searchField
                Layout.fillWidth: true
                font.pixelSize: 22 // t22 title1 [HIG]
                placeholderText: "Buscar en Spotlight"
                placeholderTextColor: "#EBEBF5"
                opacity: 1
                color: "#FFFFFF" // label dark [HIG]
                background: null
                Accessible.name: "Campo de búsqueda Spotlight"
                onTextChanged: searchDebounce.restart()
                onAccepted: {
                    if (root.filtered.length > 0)
                        backend.activate(indexOf(root.filtered[root.currentIndex]));
                }
                // Debounce 200ms: evita relanzar KRunner por cada tecla
                // (doble launchQuery deja a RunnerManager sin queryFinished).
                Timer {
                    id: searchDebounce
                    interval: 200
                    repeat: false
                    onTriggered: root.doSearch()
                }
                function indexOf(item) {
                    var all = backend.matches;
                    for (var i = 0; i < all.length; i++)
                        if (all[i].text === item.text && all[i].subtext === item.subtext)
                            return i;
                    return root.currentIndex;
                }
                Keys.onPressed: function (event) {
                    if (event.key === Qt.Key_Down) {
                        root.currentIndex = Math.min(root.currentIndex + 1, root.filtered.length - 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        root.currentIndex = Math.max(root.currentIndex - 1, 0);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        root.visible = false;
                        event.accepted = true;
                    } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_4 && (event.modifiers & Qt.MetaModifier)) {
                        var tabs = ["apps", "files", "actions", "clipboard"];
                        root.tab = tabs[event.key - Qt.Key_1];
                        root.doSearch();
                        event.accepted = true;
                    }
                }
            }
            Text {
                visible: backend.querying
                text: "…"
                color: "#0A84FF" // accent dark [HIG]
                font.pixelSize: 22
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: "#38383A"
        }

        // Resultados + preview lateral.
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            ListView {
                id: results
                Layout.preferredWidth: 400
                Layout.fillHeight: true
                Layout.margins: 8
                model: root.filtered
                currentIndex: root.currentIndex
                onCurrentIndexChanged: root.currentIndex = currentIndex
                clip: true
                spacing: 2
                Accessible.name: "Resultados"
                delegate: Rectangle {
                    width: results.width
                    height: 44
                    radius: 8 // r-sm §2.3
                    color: index === root.currentIndex ? "#0A84FF" : "transparent" // accent dark
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8
                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 6
                            color: "#1C1C1E" // bg2 dark
                            Text {
                                anchors.centerIn: parent
                                // Quick Key por posición VISIBLE (A–L); el backend
                                // numera sobre todos los matches sin filtrar.
                                text: index < 12 ? "ABCDEFGHIJKL".charAt(index) : "▤"
                                color: "#FFFFFF"
                                font.pixelSize: 13
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: modelData.text
                                color: "#FFFFFF"
                                font.pixelSize: 13 // t13 body [HIG]
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.subtext
                                color: "#EBEBF5" // label2 dark [HIG]
                                opacity: 0.6
                                font.pixelSize: 12 // t12 [HIG]
                                elide: Text.ElideRight
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.currentIndex = index;
                            backend.activate(index);
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: "#38383A"
            }

            // Preview lateral (contrato §3: preview derecha).
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 16
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: root.filtered.length > 0 ? root.filtered[root.currentIndex].text : "Sin resultados"
                    color: "#FFFFFF"
                    font.pixelSize: 17 // t17 title2 [HIG]
                    font.bold: true
                    wrapMode: Text.Wrap
                }
                Text {
                    Layout.fillWidth: true
                    text: root.filtered.length > 0 ? root.filtered[root.currentIndex].subtext : "Escribe para buscar con KRunner"
                    color: "#EBEBF5"
                    opacity: 0.6
                    font.pixelSize: 13
                    wrapMode: Text.Wrap
                }
                Text {
                    visible: root.filtered.length > 0
                    text: root.filtered.length > 0 ? ("Motor: " + root.filtered[root.currentIndex].runner) : ""
                    color: "#EBEBF5"
                    opacity: 0.3
                    font.pixelSize: 11 // t11 [HIG]
                }
                Item {
                    Layout.fillHeight: true
                }
                Text {
                    text: root.lastQuery !== "" ? ("Latencia: " + backend.lastLatencyMs + " ms · " + root.filtered.length + " resultados") : ""
                    color: "#0A84FF"
                    font.pixelSize: 11
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: "#38383A"
        }

        // Footer Cmd+1..4 + Quick Keys.
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            spacing: 16
            Repeater {
                model: [["apps", "⌘1"], ["files", "⌘2"], ["actions", "⌘3"], ["clipboard", "⌘4"]]
                delegate: Text {
                    text: (root.tab === modelData[0] ? "● " : "○ ") + root.tabNames[modelData[0]] + " " + modelData[1]
                    color: root.tab === modelData[0] ? "#0A84FF" : "#EBEBF5"
                    opacity: root.tab === modelData[0] ? 1.0 : 0.6
                    font.pixelSize: 11
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.tab = modelData[0];
                            root.doSearch();
                        }
                    }
                }
            }
            Item {
                Layout.fillWidth: true
            }
            Text {
                text: "Quick Keys A–L · Esc cierra"
                color: "#EBEBF5"
                opacity: 0.3
                font.pixelSize: 11
            }
        }
    }
}
