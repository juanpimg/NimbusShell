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
    property string clipView: "history" // history | emoji (solo tab clipboard)
    property string emojiCategory: "" // "" = todas
    property var tabNames: ({
            "apps": "Apps",
            "files": "Archivos",
            "actions": "Acciones",
            "clipboard": "Portapapeles"
        })
    property var filtered: []
    property string lastQuery: ""
    property int clipLatency: -1 // F6-T06: latencia síncrona clips/emoji
    // F6-T02: locales primero; KRunner solo como fallback (Tab o botón).
    property bool krunnerMode: false

    function refreshFilter() {
        // F6-T06: clipboard/emoji son síncronos (sin señal): se recomputan.
        if (root.tab === "clipboard") {
            root.doSearch();
            return;
        }
        var all = root.krunnerMode ? backend.matches : nimbus.localMatches;
        var q = searchField.text;
        root.lastQuery = q;
        root.filtered = all.filter(function (m) {
            return m.category === root.tab;
        });
        // Si la pestaña queda vacía pero hay resultados, mostrar todos.
        if (root.filtered.length === 0 && all.length > 0 && q !== "")
            root.filtered = all;
        root.currentIndex = 0;
    }

    function doSearch() {
        // F6-T06: clipboard local (klipper→history2.lst→wl-paste) y emoji
        // propios; sin KRunner (R-KRUNNER: sin passwords/Universal Clipboard).
        if (root.tab === "clipboard" && !root.krunnerMode) {
            root.lastQuery = searchField.text;
            if (root.clipView === "emoji")
                root.filtered = nimbus.emojiList(searchField.text, root.emojiCategory);
            else
                root.filtered = nimbus.clipboardEntries(searchField.text);
            root.clipLatency = nimbus.lastClipLatency();
            root.currentIndex = 0;
            return;
        }
        if (root.krunnerMode)
            backend.search(searchField.text);
        else {
            // Fast-path local (<50ms); si no hay nada, cae a KRunner solo.
            nimbus.searchLocal(searchField.text, root.tab);
            if (nimbus.localMatches.length === 0 && searchField.text.trim() !== "")
                backend.search(searchField.text);
        }
    }

    function useKRunner() {
        root.krunnerMode = true;
        nimbus.requestKRunner();
        backend.search(searchField.text);
    }

    function activateCurrent(action) {
        if (root.filtered.length === 0)
            return;
        // F6-T06: Pegar/Copiar copia el texto completo y cierra el overlay.
        // (Autopegado en la app destino: no implementado, ver evidencia.)
        if (root.tab === "clipboard" && !root.krunnerMode) {
            var item = root.filtered[root.currentIndex];
            if (item.localKind === "emoji")
                nimbus.recordEmoji(item.localExec);
            else
                nimbus.recordUse(item.localId);
            if (nimbus.copyToClipboard(item.localExec))
                root.visible = false;
            return;
        }
        if (root.krunnerMode)
            backend.activate(indexOf(root.filtered[root.currentIndex]));
        else
            nimbus.activateLocal(root.currentIndex, action === undefined ? "open" : action);
    }

    Connections {
        target: backend
        function onMatchesChanged() {
            if (root.krunnerMode)
                root.refreshFilter();
        }
    }

    Connections {
        target: nimbus
        function onLocalMatchesChanged() {
            if (!root.krunnerMode)
                root.refreshFilter();
        }
    }

    Component.onCompleted: {
        // Test nested: pestaña/vista iniciales (--tab/--clipview).
        if (initialTab === "apps" || initialTab === "files" || initialTab === "actions" || initialTab === "clipboard")
            root.tab = initialTab;
        if (initialClipView === "emoji" || initialClipView === "history")
            root.clipView = initialClipView;
        if (initialQuery !== "")
            searchField.text = initialQuery;
            // onTextChanged+debounce lanza
        else
            root.doSearch(); // clipboard con consulta vacía no dispara debounce
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
                onTextChanged: {
                    root.krunnerMode = false; // cada tecla vuelve al fast-path
                    searchDebounce.restart();
                }
                onAccepted: root.activateCurrent("open")
                // Debounce 200ms: evita relanzar KRunner por cada tecla
                // (doble launchQuery deja a RunnerManager sin queryFinished).
                Timer {
                    id: searchDebounce
                    interval: 200
                    repeat: false
                    onTriggered: root.doSearch()
                }
                function indexOf(item) {
                    var all = root.krunnerMode ? backend.matches : nimbus.localMatches;
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
                    } else if (event.key === Qt.Key_Tab) {
                        // Fallback explícito a KRunner (contrato F6-T02).
                        // F6-T06: en Portapapeles no hay fallback (datos locales).
                        if (root.tab !== "clipboard")
                            root.useKRunner();
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

        // F6-T06: sub-vistas de Portapapeles (Cmd+4): Historial | Emoji.
        RowLayout {
            visible: root.tab === "clipboard"
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            spacing: 8
            Repeater {
                model: [["history", qsTr("Historial")], ["emoji", qsTr("Emoji")]]
                delegate: Rectangle {
                    width: 90
                    height: 22
                    radius: 11
                    color: root.clipView === modelData[0] ? "#0A84FF" : "transparent"
                    border.color: "#0A84FF"
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: modelData[1]
                        color: root.clipView === modelData[0] ? "#FFFFFF" : "#0A84FF"
                        font.pixelSize: 11
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.clipView = modelData[0];
                            root.doSearch();
                        }
                    }
                }
            }
            // Filtro por categoría emoji (i18n preparada: qsTr).
            ComboBox {
                visible: root.clipView === "emoji"
                Layout.preferredWidth: 140
                Layout.preferredHeight: 24
                model: ["", "caras", "gestos", "animales", "comida", "naturaleza", "objetos", "simbolos", "viajes"]
                displayText: root.emojiCategory === "" ? qsTr("Todas") : root.emojiCategory
                Accessible.name: qsTr("Categoría de emoji")
                onActivated: function (index) {
                    root.emojiCategory = index === 0 ? "" : model[index];
                    root.doSearch();
                }
            }
            Item {
                Layout.fillWidth: true
            }
            Text {
                visible: root.clipView === "history"
                text: qsTr("Enter: copiar y cerrar")
                color: "#EBEBF5"
                opacity: 0.4
                font.pixelSize: 11
            }
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
                            root.activateCurrent("open");
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
                // Acciones locales (F6-T02): Abrir / Copiar / Revelar.
                // F6-T06: en Portapapeles solo Copiar/Pegar (copia y cierra).
                RowLayout {
                    visible: root.filtered.length > 0 && !root.krunnerMode
                    spacing: 8
                    Repeater {
                        model: (root.tab === "clipboard") ? [["copy", qsTr("Copiar")], ["copy", qsTr("Pegar")]] : [["open", "Abrir"], ["copy", "Copiar"], ["reveal", "Revelar"]]
                        delegate: Rectangle {
                            width: 72
                            height: 28
                            radius: 6
                            color: "#0A84FF"
                            Text {
                                anchors.centerIn: parent
                                text: modelData[1]
                                color: "#FFFFFF"
                                font.pixelSize: 12
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.activateCurrent(modelData[0])
                            }
                        }
                    }
                }
                // Fallback KRunner explícito (Tab o clic; no en Portapapeles).
                Rectangle {
                    visible: !root.krunnerMode && root.lastQuery !== "" && root.tab !== "clipboard"
                    Layout.fillWidth: true
                    height: 28
                    radius: 6
                    color: "transparent"
                    border.color: "#0A84FF"
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "Buscar en KRunner (Tab)"
                        color: "#0A84FF"
                        font.pixelSize: 12
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.useKRunner()
                    }
                }
                Text {
                    visible: root.krunnerMode
                    text: "Motor: KRunner (fallback)"
                    color: "#0A84FF"
                    font.pixelSize: 11
                }
                Text {
                    text: root.lastQuery !== "" ? ("Latencia: " + (root.tab === "clipboard" ? root.clipLatency : (root.krunnerMode ? backend.lastLatencyMs : nimbus.localLatencyMs)) + " ms · " + root.filtered.length + " resultados" + (root.krunnerMode ? " · KRunner" : " · Nimbus")) : ""
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
                text: "Quick Keys A–L · Tab=KRunner · Esc cierra"
                color: "#EBEBF5"
                opacity: 0.3
                font.pixelSize: 11
            }
        }
    }
}
